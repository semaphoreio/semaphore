require "spec_helper"

RSpec.describe HookDelivery do
  include ActiveSupport::Testing::TimeHelpers

  let(:workflow) { FactoryBot.create(:workflow) }
  let(:worker) { Semaphore::RepoHost::Hooks::Handler::DeliveryWorker }

  before do
    Sidekiq::Worker.clear_all
    allow(Watchman).to receive(:increment)
  end

  def store(workflow_id, **attributes)
    described_class.create!({
      :workflow_id => workflow_id,
      :job_id => SecureRandom.hex(12),
      :next_attempt_at => Time.current + described_class::QUEUE_LEASE
    }.merge(attributes))
  end

  describe ".start" do
    it "stores a delivery whose lease covers the job waiting in the queue" do
      freeze_time do
        delivery = described_class.start(workflow.id)

        expect(delivery.reload).to have_attributes(:retries => 0, :stale_attempts => 0, :started_at => nil)
        expect(delivery.next_attempt_at).to eq(Time.current + described_class::QUEUE_LEASE)
      end

      expect(worker.jobs).to be_empty
    end
  end

  describe ".push" do
    it "pushes a job that carries only the workflow id, under the stored job id" do
      delivery = described_class.start(workflow.id)

      job_id = described_class.push(workflow.id, delivery.job_id)

      expect(job_id).to eq(delivery.job_id)
      expect(worker.jobs.map { |job| [job["args"], job["jid"]] }).to eq([[[workflow.id], delivery.job_id]])
    end
  end

  describe ".schedule" do
    it "hands the delivery to a new job that runs after the delay" do
      old = store(workflow.id)

      freeze_time do
        job_id = described_class.schedule(workflow.id, 2.minutes, :retries => 1, :stale_attempts => 0)

        delivery = described_class.find(workflow.id)
        expect(delivery).to have_attributes(:job_id => job_id, :retries => 1, :stale_attempts => 0)
        expect(delivery.next_attempt_at).to eq(Time.current + 2.minutes + described_class::QUEUE_LEASE)
        expect(job_id).not_to eq(old.job_id)

        job = worker.jobs.last
        expect([job["args"], job["jid"], job["at"]]).to eq([[workflow.id], job_id, (Time.current + 2.minutes).to_f])
      end
    end

    it "creates the delivery of a workflow that has none" do
      described_class.schedule(workflow.id, 2.minutes, :retries => 1, :stale_attempts => 0)

      expect(described_class.find(workflow.id).retries).to eq(1)
    end

    it "pushes a job that runs right away when there is no delay" do
      described_class.schedule(workflow.id, 0, :retries => 1, :stale_attempts => 0)

      expect(worker.jobs.last).not_to have_key("at")
    end

    it "supersedes the job that held the delivery" do
      old = store(workflow.id)

      described_class.schedule(workflow.id, 2.minutes, :retries => 1, :stale_attempts => 0)

      expect(described_class.claim(workflow.id, old.job_id)).to be_nil
    end
  end

  describe ".claim" do
    it "lets only the named job run the delivery, once at a time" do
      delivery = store(workflow.id)

      expect(described_class.claim(workflow.id, "another-job")).to be_nil

      freeze_time do
        claimed = described_class.claim(workflow.id, delivery.job_id)
        expect(claimed.started_at).to eq(Time.current)
        expect(claimed.next_attempt_at).to eq(Time.current + described_class::RUN_LEASE)
      end

      expect(described_class.claim(workflow.id, delivery.job_id)).to be_nil

      described_class.release(workflow.id, delivery.job_id)
      expect(described_class.claim(workflow.id, delivery.job_id)).to be_present
    end
  end

  describe ".finish" do
    it "deletes the delivery only for the job that holds it" do
      delivery = store(workflow.id)

      described_class.finish(workflow.id, "another-job")
      expect(described_class.exists?(workflow.id)).to be(true)

      described_class.finish(workflow.id, delivery.job_id)
      expect(described_class.exists?(workflow.id)).to be(false)
    end
  end

  describe ".await_retry" do
    it "moves the lease past the retry" do
      delivery = store(workflow.id)

      freeze_time do
        described_class.await_retry(workflow.id, delivery.job_id, 40)

        expect(delivery.reload.next_attempt_at).to eq(Time.current + 40 + described_class::QUEUE_LEASE)
      end
    end
  end

  describe ".sweep" do
    it "leaves deliveries alone until their lease runs out" do
      described_class.schedule(workflow.id, 2.minutes, :retries => 1, :stale_attempts => 0)
      Sidekiq::Worker.clear_all

      travel(2.minutes + described_class::QUEUE_LEASE - 1.second) do
        expect { described_class.sweep }.not_to(change { described_class.find(workflow.id).attributes })
      end

      expect(worker.jobs).to be_empty
    end

    it "pushes the job of an expired delivery again under the same job id" do
      delivery = store(workflow.id, :next_attempt_at => 1.second.ago)

      described_class.sweep

      expect(worker.jobs.map { |job| [job["args"], job["jid"]] }).to eq([[[workflow.id], delivery.job_id]])
      expect(delivery.reload).to have_attributes(:interrupted_runs => 0, :started_at => nil)
      expect(delivery.next_attempt_at).to be > Time.current
      expect(Watchman).to have_received(:increment).with("hooks.delivery.redriven")
    end

    it "pushes each expired delivery once until its new lease runs out" do
      store(workflow.id, :next_attempt_at => 1.second.ago)

      described_class.sweep
      described_class.sweep

      expect(worker.jobs.size).to eq(1)
    end

    it "counts a run that was cut short and lets the pushed job claim it again" do
      delivery = store(workflow.id)
      described_class.claim(workflow.id, delivery.job_id)

      travel(described_class::RUN_LEASE + 1.second) do
        described_class.sweep

        expect(delivery.reload).to have_attributes(:interrupted_runs => 1, :started_at => nil)
        expect(described_class.claim(workflow.id, delivery.job_id)).to be_present
      end
    end

    it "drops a delivery whose runs keep getting cut short" do
      delivery = store(workflow.id, :interrupted_runs => described_class::MAX_INTERRUPTED_RUNS - 1)
      described_class.claim(workflow.id, delivery.job_id)

      travel(described_class::RUN_LEASE + 1.second) do
        described_class.sweep
      end

      expect(described_class.exists?(workflow.id)).to be(false)
      expect(worker.jobs).to be_empty
      expect(Watchman).to have_received(:increment).with("hooks.delivery.abandoned")
    end

    it "takes expired deliveries in batches" do
      stub_const("HookDelivery::SWEEP_BATCH_SIZE", 2)
      3.times { store(SecureRandom.uuid, :next_attempt_at => 1.second.ago) }

      described_class.sweep

      expect(worker.jobs.size).to eq(3)
    end
  end
end
