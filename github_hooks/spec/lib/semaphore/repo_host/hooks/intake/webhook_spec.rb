require "spec_helper"

RSpec.describe Semaphore::RepoHost::Hooks::Intake::Webhook do
  include IntakeQueueHelper

  let(:project) { FactoryBot.create(:project) }
  let(:json) { File.read(Rails.root.join("fixtures/github_payloads/many_commits.json").to_s) }

  describe "#request" do
    it "records the body of a JSON hook as its payload" do
      webhook = build_intake_webhook(project, :body => json)

      expect(webhook.request).to eq("hash_id" => project.id, "payload" => json)
    end

    it "records the decoded payload field of a form hook" do
      webhook = build_intake_webhook(project, :body => "payload=#{CGI.escape(json)}", :content_type => described_class::FORM_CONTENT_TYPE)

      expect(webhook.request["payload"]).to eq(json)
    end

    it "leaves out the project id of a hook that did not name one" do
      webhook = build_intake_webhook(project, :hash_id => nil)

      expect(webhook.request).not_to have_key("hash_id")
    end
  end

  describe "#signed_body" do
    it "keeps the bytes the signature was computed over" do
      body = "{\"name\":\"café\"}".b
      webhook = build_intake_webhook(project, :body => body)

      expect(webhook.signed_body.bytes).to eq(body.bytes)
      expect(webhook.signed_body.encoding).to eq(Encoding::UTF_8)
    end
  end

  describe ".from_message" do
    it "reads back what the hook was published as, the body byte for byte" do
      body = "{\"name\":\"caf\xC3\xA9\"}\n\n{\"broken\":\"\xFF\xFE\"}\r\n".b
      webhook = build_intake_webhook(project, :body => body, :received_at => Time.zone.parse("2026-11-17T10:00:00.123456Z"))

      copy = described_class.from_message(webhook.to_message)

      expect(copy.body.bytes).to eq(body.bytes)
      expect(copy).to have_attributes(
        :workflow_id => webhook.workflow_id, :project_id => project.id, :signature => webhook.signature,
        :content_type => webhook.content_type, :received_at => webhook.received_at, :hash_id => webhook.hash_id,
        :event => "push", :delivery_id => webhook.delivery_id
      )
    end

    it "reads back a hook without the optional fields" do
      webhook = build_intake_webhook(project, :hash_id => nil, :event => nil, :delivery_id => nil, :body => "")

      copy = described_class.from_message(webhook.to_message)

      expect(copy).to have_attributes(:hash_id => nil, :event => nil, :delivery_id => nil, :body => "")
    end
  end

  describe "#to_message" do
    it "publishes a header value that is not valid UTF-8 instead of failing the request" do
      webhook = build_intake_webhook(project, :signature => "sha256=\xFF".b)

      expect(described_class.from_message(webhook.to_message).signature).to eq("sha256=�")
    end
  end
end
