# A verified GitHub hook from the moment its workflow is recorded until it reaches a
# final state. The row, not the Sidekiq job, records the pending work: jobs carry only
# the workflow id, and only the job named in `job_id` may run the delivery.
class HookDelivery < ActiveRecord::Base
  self.primary_key = :workflow_id

  # Past `next_attempt_at` nobody holds the delivery and the sweeper pushes its job
  # again. A pushed job gets QUEUE_LEASE after it is due, a claimed run RUN_LEASE.
  QUEUE_LEASE = 10.minutes
  RUN_LEASE = 10.minutes
  # Runs that ended without a hand-off (the worker died) before the delivery is dropped.
  MAX_INTERRUPTED_RUNS = 3
  SWEEP_BATCH_SIZE = 500
  SWEEP_MAX_BATCHES = 20

  # Stores the delivery of a workflow whose hook was verified. Its job is pushed by
  # `push` once the surrounding transaction commits.
  def self.start(workflow_id)
    create!(:workflow_id => workflow_id, :job_id => new_job_id, :next_attempt_at => Time.current + QUEUE_LEASE)
  end

  # Hands the delivery of `workflow_id` to a new job that runs after `delay`. An upsert,
  # because an approval resumes the workflow it unblocked.
  def self.schedule(workflow_id, delay, retries:, stale_attempts:)
    now = Time.current
    job_id = new_job_id
    values = [workflow_id, job_id, retries, stale_attempts, now + delay + QUEUE_LEASE, now, now]

    connection.exec_update(sanitize_sql_array([<<~SQL, *values]), "HookDelivery Schedule")
      INSERT INTO hook_deliveries
        (workflow_id, job_id, retries, stale_attempts, next_attempt_at, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT (workflow_id) DO UPDATE SET
        job_id = EXCLUDED.job_id,
        retries = EXCLUDED.retries,
        stale_attempts = EXCLUDED.stale_attempts,
        next_attempt_at = EXCLUDED.next_attempt_at,
        started_at = NULL,
        updated_at = EXCLUDED.updated_at
    SQL

    push(workflow_id, job_id, delay)
  end

  # rubocop:disable Rails/SkipsModelValidations
  # Each write below is one conditional statement; the model has no validations.

  # Marks the delivery as run by `job_id`. Nil when another job holds it, a run is in
  # progress, or it finished.
  def self.claim(workflow_id, job_id)
    now = Time.current
    claimed = where(:workflow_id => workflow_id, :job_id => job_id, :started_at => nil)
              .update_all(:started_at => now, :next_attempt_at => now + RUN_LEASE, :updated_at => now)

    find_by(:workflow_id => workflow_id) if claimed == 1
  end

  # Ends a run that did not hand the delivery to another job.
  def self.finish(workflow_id, job_id)
    where(:workflow_id => workflow_id, :job_id => job_id).delete_all
  end

  # Lets a pushed-back or retried copy of the same job claim the delivery again.
  def self.release(workflow_id, job_id)
    where(:workflow_id => workflow_id, :job_id => job_id)
      .where.not(:started_at => nil)
      .update_all(:started_at => nil, :updated_at => Time.current)
  end

  # Keeps the sweeper away while Sidekiq holds the job for a retry `delay` from now.
  def self.await_retry(workflow_id, job_id, delay)
    now = Time.current
    where(:workflow_id => workflow_id, :job_id => job_id)
      .update_all(:next_attempt_at => now + delay + QUEUE_LEASE, :updated_at => now)
  end
  # rubocop:enable Rails/SkipsModelValidations

  # Pushes the job of every delivery whose lease ran out, under the same job id, so a
  # copy that was only late and the new one cannot both run it.
  def self.sweep
    SWEEP_MAX_BATCHES.times do
      expired = take_expired(SWEEP_BATCH_SIZE)
      expired.each { |row| redrive(row["workflow_id"], row["job_id"], row["interrupted_runs"]) }

      break if expired.size < SWEEP_BATCH_SIZE
    end
  end

  # Extends the lease of expired deliveries and counts the runs they lost.
  def self.take_expired(limit)
    now = Time.current

    connection.exec_query(sanitize_sql_array([<<~SQL, now + QUEUE_LEASE, now, now, limit]), "HookDelivery Sweep").to_a
      UPDATE hook_deliveries AS d SET
        next_attempt_at = ?,
        interrupted_runs = d.interrupted_runs + CASE WHEN d.started_at IS NULL THEN 0 ELSE 1 END,
        started_at = NULL,
        updated_at = ?
      WHERE d.workflow_id IN (
        SELECT workflow_id FROM hook_deliveries
        WHERE next_attempt_at < ?
        ORDER BY next_attempt_at
        LIMIT ?
        FOR UPDATE SKIP LOCKED
      )
      RETURNING d.workflow_id, d.job_id, d.interrupted_runs
    SQL
  end

  def self.redrive(workflow_id, job_id, interrupted_runs)
    if interrupted_runs >= MAX_INTERRUPTED_RUNS
      finish(workflow_id, job_id)
      Watchman.increment("hooks.delivery.abandoned")
      Logman.error("hook-delivery-abandoned", :workflow_id => workflow_id, :interrupted_runs => interrupted_runs)
    else
      push(workflow_id, job_id)
      Watchman.increment("hooks.delivery.redriven")
      Logman.info("hook-delivery-redriven", :workflow_id => workflow_id, :interrupted_runs => interrupted_runs)
    end
  end

  # Returns the job id.
  def self.push(workflow_id, job_id, delay = 0)
    item = { "class" => Semaphore::RepoHost::Hooks::Handler::DeliveryWorker, "args" => [workflow_id], "jid" => job_id }
    item["at"] = (Time.now + delay).to_f if delay.positive?

    Sidekiq::Client.push(item)
  end

  def self.new_job_id
    SecureRandom.hex(12)
  end

  private_class_method :take_expired, :redrive, :new_job_id

  # Deliveries are stored only after their hook's signature was verified.
  def verified?
    true
  end

  def reschedule(workflow_id, delay, retries, stale_attempts)
    self.class.schedule(workflow_id, delay, :retries => retries, :stale_attempts => stale_attempts)
  end
end
