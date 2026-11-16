require "spec_helper"

RSpec.describe Semaphore::RepoHost::Hooks::Handler::DeliveryWorker do
  include ActiveSupport::Testing::TimeHelpers

  let(:workflow) { FactoryBot.create(:workflow) }
  let(:handler) { Semaphore::RepoHost::Hooks::Handler }

  before do
    Sidekiq::Worker.clear_all
    allow(Watchman).to receive(:increment)
  end

  def enqueue(workflow)
    delivery = HookDelivery.start(workflow.id)
    HookDelivery.push(workflow.id, delivery.job_id)
  end

  def perform(job_id)
    worker = described_class.new
    worker.jid = job_id
    worker.perform(workflow.id)
  end

  describe "#perform" do
    it "runs the handler with the delivery and finishes it" do
      job_id = enqueue(workflow)

      expect(handler).to receive(:run) do |run_workflow, _logger, delivery:|
        expect(run_workflow).to eq(workflow)
        expect(delivery).to have_attributes(:workflow_id => workflow.id, :job_id => job_id)
      end

      perform(job_id)

      expect(HookDelivery.exists?(workflow.id)).to be(false)
    end

    it "keeps a delivery the run handed to another job" do
      job_id = enqueue(workflow)
      allow(handler).to receive(:run) do
        HookDelivery.schedule(workflow.id, 2.minutes, :retries => 1, :stale_attempts => 0)
      end

      perform(job_id)

      delivery = HookDelivery.find(workflow.id)
      expect(delivery.job_id).not_to eq(job_id)
      expect(delivery.started_at).to be_nil
    end

    it "does nothing for a job that does not hold the delivery" do
      enqueue(workflow)

      expect(handler).not_to receive(:run)

      perform("superseded-job")
    end

    it "does nothing for a delivery that already finished" do
      expect(handler).not_to receive(:run)

      perform("finished-job")
    end

    it "lets Sidekiq retry the same job after an error" do
      job_id = enqueue(workflow)
      allow(handler).to receive(:run).and_raise(RepoHost::RemoteException::ServiceUnavailable)

      expect { perform(job_id) }.to raise_error(RepoHost::RemoteException::ServiceUnavailable)

      expect(HookDelivery.find(workflow.id).started_at).to be_nil
      expect(HookDelivery.claim(workflow.id, job_id)).to be_present
    end

    it "finishes the delivery of a workflow that no longer exists" do
      job_id = enqueue(workflow)
      workflow.delete

      expect(handler).not_to receive(:run)

      perform(job_id)

      expect(HookDelivery.exists?(workflow.id)).to be(false)
    end
  end

  describe "when Sidekiq retries the job" do
    it "keeps the sweeper away until the retry is due" do
      job_id = enqueue(workflow)

      freeze_time do
        delay = described_class.sidekiq_retry_in_block.call(3, StandardError.new, { "args" => [workflow.id], "jid" => job_id })

        expect(delay).to eq((3**4) + 15)
        expect(HookDelivery.find(workflow.id).next_attempt_at).to eq(Time.current + delay + 40 + HookDelivery::QUEUE_LEASE)
      end
    end
  end

  describe "when Sidekiq retries are exhausted" do
    it "drops the delivery and releases an approval claim the failed job held" do
      job_id = enqueue(workflow)
      workflow.update(:state => Workflow::STATE_PR_APPROVAL_IN_PROGRESS)

      described_class.sidekiq_retries_exhausted_block.call({ "args" => [workflow.id], "jid" => job_id }, StandardError.new)

      expect(HookDelivery.exists?(workflow.id)).to be(false)
      expect(workflow.reload.state).to eq(Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR)
    end

    it "leaves other workflows alone" do
      workflow.update(:state => Workflow::STATE_LAUNCHING)

      described_class.sidekiq_retries_exhausted_block.call({ "args" => [workflow.id], "jid" => "job" }, StandardError.new)

      expect(workflow.reload.state).to eq(Workflow::STATE_LAUNCHING)
    end
  end

  describe "recovering a delivery whose worker died" do
    before do
      allow(handler).to receive(:launch_pipeline) { |_branch, wf, _logger| wf.update(:state => Workflow::STATE_LAUNCHING) }
      allow(handler).to receive(:webhook_signature_valid?)
    end

    # The worker claimed the delivery and was killed mid-run; Redis lost the job with it.
    def kill_worker_mid_run(job_id)
      HookDelivery.claim(workflow.id, job_id)
      Sidekiq::Worker.clear_all
    end

    def run_pushed_jobs
      described_class.jobs.dup.each do |job|
        described_class.jobs.delete(job)
        perform(job["jid"])
      end
    end

    it "processes a delivery left processing with no job exactly once" do
      job_id = enqueue(workflow)
      kill_worker_mid_run(job_id)

      expect(handler).to receive(:run).once.and_call_original

      travel(HookDelivery::RUN_LEASE + 1.second) do
        RecurringTasks::HookDeliverySweeper.new.perform
        run_pushed_jobs
      end

      travel(HookDelivery::RUN_LEASE + HookDelivery::QUEUE_LEASE + 2.minutes) do
        RecurringTasks::HookDeliverySweeper.new.perform
        run_pushed_jobs
      end

      expect(workflow.reload.state).to eq(Workflow::STATE_LAUNCHING)
      expect(HookDelivery.exists?(workflow.id)).to be(false)
    end

    it "runs a late job and the job the sweeper pushed for it only once" do
      job_id = enqueue(workflow)

      expect(handler).to receive(:run).once.and_call_original

      travel(HookDelivery::QUEUE_LEASE + 1.second) do
        RecurringTasks::HookDeliverySweeper.new.perform

        expect(described_class.jobs.map { |job| job["jid"] }).to eq([job_id, job_id])
        run_pushed_jobs
      end

      expect(workflow.reload.state).to eq(Workflow::STATE_LAUNCHING)
    end

    it "does not check the signature of a stored delivery again" do
      job_id = enqueue(workflow)

      perform(job_id)

      expect(handler).not_to have_received(:webhook_signature_valid?)
      expect(workflow.reload.state).to eq(Workflow::STATE_LAUNCHING)
    end
  end
end
