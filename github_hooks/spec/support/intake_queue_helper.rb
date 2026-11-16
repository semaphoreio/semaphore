# Direct access to the hook intake queues on the test broker.
module IntakeQueueHelper
  # Declares the exchanges and queues the way the tackle consumer does.
  def with_intake_channel
    session = Bunny.new(App.amqp_url)
    session.start
    options = Semaphore::RepoHost::Hooks::Intake.consumer_options(:connection => session, :logger => Logger.new(nil))
    Tackle::Consumer.new(Tackle::Consumer::Params.new(options))

    yield session.create_channel
  ensure
    session&.close
  end

  def intake_queue
    Semaphore::RepoHost::Hooks::Intake::QUEUE
  end

  def intake_delay_queue
    "#{intake_queue}.delay.#{Semaphore::RepoHost::Hooks::Intake::RETRY_DELAY.to_i}"
  end

  def intake_dead_queue
    "#{intake_queue}.dead"
  end

  def purge_intake_queues
    with_intake_channel do |channel|
      [intake_queue, intake_delay_queue, intake_dead_queue].each { |queue| channel.queue_purge(queue) }
    end
  end

  def intake_queue_depth(queue = intake_queue)
    with_intake_channel { |channel| channel.queue(queue, :passive => true).message_count }
  end

  # Returns [properties, body] of the next message, or nil.
  def pop_intake_message(queue = intake_queue)
    with_intake_channel do |channel|
      _delivery_info, properties, body = channel.basic_get(queue, :manual_ack => false)

      [Bunny::MessageProperties.new(properties), body] if body
    end
  end

  def build_intake_webhook(project, **attributes)
    Semaphore::RepoHost::Hooks::Intake::Webhook.new(**{
      :workflow_id => SecureRandom.uuid,
      :project_id => project.id,
      :body => File.read(Rails.root.join("fixtures/github_payloads/many_commits.json").to_s),
      :signature => "sha256=signature",
      :content_type => "application/json",
      :received_at => Time.current.change(:usec => 0),
      :hash_id => project.id,
      :event => "push",
      :delivery_id => SecureRandom.uuid
    }.merge(attributes))
  end
end
