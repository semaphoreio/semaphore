require "spec_helper"

RSpec.describe Semaphore::RepoHost::Hooks::Intake::Processor do
  include IntakeQueueHelper

  let(:project) { FactoryBot.create(:project) }
  let(:handler) { Semaphore::RepoHost::Hooks::Handler }
  let(:delivery_worker) { Semaphore::RepoHost::Hooks::Handler::DeliveryWorker }
  let(:webhook) { build_intake_webhook(project) }

  before do
    Sidekiq::Worker.clear_all
    allow(Watchman).to receive(:increment)
    allow(handler).to receive(:webhook_signature_valid?).and_return(:ok)
  end

  it "records a verified hook under the id it was accepted with and enqueues it by that id" do
    expect(described_class.process(webhook)).to eq(:recorded)

    workflow = Workflow.find(webhook.workflow_id)
    expect(workflow).to have_attributes(:project_id => project.id, :provider => "github", :state => Workflow::STATE_PROCESSING,
                                        :result => Workflow::RESULT_OK, :received_at => webhook.received_at)
    expect(workflow.request).to eq(webhook.request)
    expect(workflow.commit_sha).to eq(workflow.payload.head)

    delivery = HookDelivery.find(webhook.workflow_id)
    expect(delivery_worker.jobs.map { |job| [job["args"], job["jid"]] }).to eq([[[webhook.workflow_id], delivery.job_id]])
  end

  it "orders a hook by when it arrived, not when it was recorded" do
    webhook = build_intake_webhook(project, :received_at => 3.minutes.ago.change(:usec => 0))

    described_class.process(webhook)

    workflow = Workflow.find(webhook.workflow_id)
    expect(workflow.created_at).to eq(webhook.received_at)
    expect(Workflow.created_before(1.minute.ago)).to include(workflow)
  end

  it "checks the signature over the body exactly as received" do
    described_class.process(webhook)

    expect(handler).to have_received(:webhook_signature_valid?)
      .with(anything, project.organization_id, project.repository.id, webhook.body, "sha256=signature")
  end

  it "records a hook delivered twice once" do
    described_class.process(webhook)

    expect(described_class.process(webhook)).to eq(:duplicate)
    expect(Workflow.where(:id => webhook.workflow_id).count).to eq(1)
    expect(delivery_worker.jobs.size).to eq(1)
  end

  it "records nothing for a hook whose signature does not match" do
    allow(handler).to receive(:webhook_signature_valid?).and_return(:not_verified)

    expect(described_class.process(webhook)).to eq(:not_verified)
    expect(Workflow.exists?(webhook.workflow_id)).to be(false)
    expect(delivery_worker.jobs).to be_empty
  end

  it "asks for another try when the signature cannot be checked" do
    allow(handler).to receive(:webhook_signature_valid?).and_return(:retry)

    expect { described_class.process(webhook) }.to raise_error(described_class::RetryLater)
    expect(Workflow.exists?(webhook.workflow_id)).to be(false)
  end

  it "raises when the workflow cannot be recorded" do
    allow(Semaphore::RepoHost::Hooks::Recorder).to receive(:record_verified_hook).and_raise(ActiveRecord::ConnectionNotEstablished)

    expect { described_class.process(webhook) }.to raise_error(ActiveRecord::ConnectionNotEstablished)
  end

  it "drops a hook for a project that no longer exists" do
    webhook = build_intake_webhook(project, :project_id => SecureRandom.uuid)

    expect(described_class.process(webhook)).to eq(:project_not_found)
    expect(handler).not_to have_received(:webhook_signature_valid?)
  end

  it "leaves a job that cannot be pushed to the sweeper" do
    allow(Sidekiq::Client).to receive(:push).and_raise(RedisClient::CannotConnectError)

    expect(described_class.process(webhook)).to eq(:recorded)
    expect(HookDelivery.exists?(webhook.workflow_id)).to be(true)
    expect(Watchman).to have_received(:increment).with("hooks.intake.enqueue_failed")
  end
end
