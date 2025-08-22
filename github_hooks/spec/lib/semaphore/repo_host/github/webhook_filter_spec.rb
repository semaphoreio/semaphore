require "spec_helper"

RSpec.describe Semaphore::RepoHost::Github::WebhookFilter do

  let(:request) { instance_double(Semaphore::RepoHost::Hooks::Request) }
  let(:filter) { Semaphore::RepoHost::Github::WebhookFilter.new(request, payload) }
  let(:org_id) { "570df438-3a41-4859-b714-cc2ea4e9c49d" }

  describe "#unavailable_payload" do

    context "payload present" do

      let(:payload) { '{"anything": "anything"}' }

      it "returns false" do
        expect(filter.unavailable_payload?).to eql(false)
      end

    end

    context "payload missing" do

      let(:payload) { "" }

      it "returns true" do
        expect(filter.unavailable_payload?).to eql(true)
      end

    end
  end

  describe "#unsuported_webhook?" do

    before { allow(request).to receive_message_chain(:raw_request, :headers).and_return(headers) }

    context "push" do

      let(:headers) { { "X-Github-Event" => "push" } }
      let(:payload) { '{"anything": "anything"}' }

      it "returns false" do
        expect(filter.unsupported_webhook?).to eql(false)
      end

    end

    context "issue_comment" do
      let(:headers) { { "X-Github-Event" => "issue_comment" } }

      context "issue comment" do
        let(:payload) { '{"issue": {}, "comment": {"body": "/sem-approve"}}' }

        it "returns true" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "pr comment with unsupported command" do
        let(:payload) { '{"issue": {"pull_request": {"url": ""}}, "comment": {"body": "/foo"}}' }

        it "returns true" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "pr comment with supported command" do
        let(:payload) { '{"issue": {"pull_request": {"url": ""}}, "comment": {"body": "asd\r\n\r\n/sem-approve"}}' }

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end
      end

    end

    context "pull_request" do

      let(:headers) { { "X-Github-Event" => "pull_request" } }

      context "opened" do

        let(:payload) do
          <<-PAYLOAD
              {
                "action": "opened",
                "pull_request":{
                  "head":{
                    "label": "owner_1:branch"
                  },
                  "base":{
                    "label": "owner_2:branch"
                  }
                }
              }
          PAYLOAD
        end

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end

      end

      context "synchronize" do

        let(:payload) do
          <<-PAYLOAD
              {
                "action": "synchronize",
                "pull_request":{
                  "head":{
                    "label": "owner_1:branch"
                  },
                  "base":{
                    "label": "owner_2:branch"
                  }
                }
              }
          PAYLOAD
        end

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end

      end

      context "closed" do

        let(:payload) do
          <<-PAYLOAD
              {
                "action": "closed",
                "pull_request":{
                  "head":{
                    "label": "owner_1:branch"
                  },
                  "base":{
                    "label": "owner_2:branch"
                  }
                }
              }
          PAYLOAD
        end

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end

      end

      context "reopened" do

        let(:payload) do
          <<-PAYLOAD
              {
                "action": "reopened",
                "pull_request":{
                  "head":{
                    "label": "owner_1:branch"
                  },
                  "base":{
                    "label": "owner_2:branch"
                  }
                }
              }
          PAYLOAD
        end

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end

      end

      context "ready_for_review" do

        let(:payload) do
          <<-PAYLOAD
              {
                "action": "ready_for_review",
                "pull_request":{
                  "draft": false,
                  "head":{
                    "label": "owner_1:branch"
                  },
                  "base":{
                    "label": "owner_2:branch"
                  }
                }
              }
          PAYLOAD
        end

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end

      end

      context "other" do

        let(:payload) do
          <<-PAYLOAD
              {
                "action": "other",
                "pull_request":{
                  "head":{
                    "label": "owner_1:branch"
                  },
                  "base":{
                    "label": "owner_2:branch"
                  }
                }
              }
          PAYLOAD
        end

        it "returns true" do
          expect(filter.unsupported_webhook?).to eql(true)
        end

      end

      context "pull request within same repo" do

        let(:payload) do
          <<-PAYLOAD
              {
                "action": "opened",
                "pull_request":{
                  "head":{
                    "label": "owner:branch"
                  },
                  "base":{
                    "label": "owner:branch"
                  }
                }
              }
          PAYLOAD
        end

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end

      end
    end

    context "other" do

      let(:headers) { { "X-Github-Event" => "other" } }
      let(:payload) { '{"anything": "anything"}' }

      it "returns true" do
        expect(filter.unsupported_webhook?).to eql(true)
      end

    end
  end
end
