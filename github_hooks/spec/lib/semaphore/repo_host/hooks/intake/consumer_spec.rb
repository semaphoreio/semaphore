require "spec_helper"

RSpec.describe Semaphore::RepoHost::Hooks::Intake::Consumer do
  include IntakeQueueHelper

  let(:project) { FactoryBot.create(:project) }
  let(:intake) { Semaphore::RepoHost::Hooks::Intake }
  let(:handler) { Semaphore::RepoHost::Hooks::Handler }
  let(:consumer) { described_class.new(:threads => 1, :logger => Logger.new(nil)) }

  before do
    purge_intake_queues
    Sidekiq::Worker.clear_all
    allow(Watchman).to receive(:increment)
    allow(handler).to receive(:webhook_signature_valid?).and_return(:ok)
  end

  after { intake::Publisher.disconnect }

  describe "#handle" do
    it "returns once the hook's workflow is recorded" do
      webhook = build_intake_webhook(project)

      consumer.handle(webhook.to_message)

      expect(Workflow.exists?(webhook.workflow_id)).to be(true)
    end

    it "returns without recording a hook whose signature does not match" do
      allow(handler).to receive(:webhook_signature_valid?).and_return(:not_verified)
      webhook = build_intake_webhook(project)

      expect { consumer.handle(webhook.to_message) }.not_to raise_error
      expect(Workflow.exists?(webhook.workflow_id)).to be(false)
    end

    it "raises for a hook that cannot be verified yet, so tackle retries it" do
      allow(handler).to receive(:webhook_signature_valid?).and_return(:retry)

      expect { consumer.handle(build_intake_webhook(project).to_message) }.to raise_error(intake::Processor::RetryLater)
      expect(Watchman).to have_received(:increment).with("hooks.intake.failed")
    end

    it "raises when the workflow cannot be recorded" do
      allow(Semaphore::RepoHost::Hooks::Recorder).to receive(:record_verified_hook).and_raise(ActiveRecord::ConnectionNotEstablished)

      expect { consumer.handle(build_intake_webhook(project).to_message) }.to raise_error(ActiveRecord::ConnectionNotEstablished)
    end

    it "records a published hook once even when the broker delivers it twice" do
      webhook = build_intake_webhook(project)
      intake::Publisher.publish([webhook])
      _properties, message = pop_intake_message

      2.times { consumer.handle(message) }

      expect(Workflow.where(:id => webhook.workflow_id).count).to eq(1)
      expect(Semaphore::RepoHost::Hooks::Handler::DeliveryWorker.jobs.map { |job| job["args"] }).to eq([[webhook.workflow_id]])
    end
  end

  describe "#consume", :multithreaded do
    let(:processor) { intake::Processor }

    def consuming
      # The consumer thread needs the connection this thread holds; CI runs with a pool of one.
      ActiveRecord::Base.connection_pool.release_connection
      thread = Thread.new { consumer.consume }
      yield
    ensure
      thread&.raise(Interrupt)
      thread&.join(10)
    end

    def wait_until(timeout = 10)
      deadline = Time.current + timeout
      sleep(0.2) until yield || Time.current > deadline
    end

    it "acknowledges a hook once its workflow is recorded" do
      webhook = build_intake_webhook(project)
      intake::Publisher.publish([webhook])

      consuming do
        wait_until { ActiveRecord::Base.connection_pool.with_connection { Workflow.exists?(webhook.workflow_id) } }
      end

      expect(Workflow.exists?(webhook.workflow_id)).to be(true)
      expect(intake_queue_depth).to eq(0)
    end

    it "moves a hook that fails to tackle's delay queue, unchanged" do
      allow(processor).to receive(:process).and_raise(processor::RetryLater)
      webhook = build_intake_webhook(project)
      intake::Publisher.publish([webhook])

      consuming { wait_until { intake_queue_depth(intake_delay_queue) == 1 } }

      expect(intake_queue_depth).to eq(0)
      properties, body = pop_intake_message(intake_delay_queue)
      expect(properties.headers).to include("retry_count" => 1)
      expect(body.bytes).to eq(webhook.to_message.bytes)
    end

    it "retries a hook RETRY_LIMIT times, then parks it in tackle's dead queue" do
      allow(processor).to receive(:process).and_raise(processor::RetryLater)
      with_intake_channel do |channel|
        [intake::RETRY_LIMIT - 1, intake::RETRY_LIMIT].each do |retries|
          channel.default_exchange.publish(build_intake_webhook(project).to_message, :routing_key => intake_queue,
                                                                                     :headers => { "retry_count" => retries })
        end
      end

      consuming { wait_until { intake_queue_depth(intake_delay_queue) + intake_queue_depth(intake_dead_queue) == 2 } }

      expect(pop_intake_message(intake_delay_queue).first.headers).to include("retry_count" => intake::RETRY_LIMIT)
      expect(intake_queue_depth(intake_dead_queue)).to eq(1)
    end
  end
end
