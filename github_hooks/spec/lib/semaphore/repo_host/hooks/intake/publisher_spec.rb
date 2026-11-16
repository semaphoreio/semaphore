require "spec_helper"

RSpec.describe Semaphore::RepoHost::Hooks::Intake::Publisher do
  include IntakeQueueHelper

  let(:project) { FactoryBot.create(:project) }
  let(:webhook_class) { Semaphore::RepoHost::Hooks::Intake::Webhook }

  before { purge_intake_queues }
  after { described_class.disconnect }

  it "stores the hook in the tackle consumer's queue as a persistent message" do
    webhook = build_intake_webhook(project, :body => "payload=%7B%22caf%C3%A9%22%7D")

    described_class.publish([webhook])

    properties, body = pop_intake_message
    expect(properties.delivery_mode).to eq(2)
    expect(body.bytes).to eq(webhook.to_message.bytes)
    expect(webhook_class.from_message(body)).to have_attributes(:workflow_id => webhook.workflow_id, :body => webhook.body)
  end

  it "stores every hook of a request" do
    described_class.publish([build_intake_webhook(project), build_intake_webhook(project)])

    expect(Array.new(3) { pop_intake_message }.compact.size).to eq(2)
  end

  it "keeps a hook accepted before any consumer declared its queue" do
    with_intake_channel { |channel| [intake_queue, intake_delay_queue, intake_dead_queue].each { |queue| channel.queue_delete(queue) } }

    described_class.publish([build_intake_webhook(project)])

    expect(pop_intake_message).to be_present
  end

  it "fails when no queue is bound to take the hook" do
    described_class.publish([build_intake_webhook(project)])
    with_intake_channel { |channel| channel.queue_delete(intake_queue) }

    expect { described_class.publish([build_intake_webhook(project)]) }.to raise_error(described_class::Error, /route/)
  end

  it "fails without publishing while the broker is blocking publishers" do
    allow_any_instance_of(Bunny::Session).to receive(:blocked?).and_return(true)

    expect { described_class.publish([build_intake_webhook(project)]) }.to raise_error(described_class::Error, /blocking/)
    expect(pop_intake_message).to be_nil
  end

  it "fails when the broker cannot be reached, then connects again" do
    allow(App).to receive(:amqp_url).and_return("amqp://127.0.0.1:1")
    expect { described_class.publish([build_intake_webhook(project)]) }.to raise_error(described_class::Error)

    allow(App).to receive(:amqp_url).and_call_original
    described_class.publish([build_intake_webhook(project)])

    expect(pop_intake_message).to be_present
  end
end
