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

      context "issue comment (not a pull request)" do
        let(:payload) { '{"action": "created", "issue": {}, "comment": {"body": "/sem-approve"}}' }

        it "returns true" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "pr comment with unsupported command only" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "/foo"}}' }

        it "returns true" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "pr comment with supported command" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "asd\r\n\r\n/sem-approve"}}' }

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end
      end

      context "pr comment with --include-cache alias" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "/sem-approve --include-cache"}}' }

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end
      end

      context "pr comment with inline sem-approve command" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "LGTM /sem-approve"}}' }

        it "returns true (command must start the line)" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "pr comment with sem-approve inside a blockquote" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "> /sem-approve --include-secrets"}}' }

        it "returns true (quoted command is inert)" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "pr comment with sem-approve inside a fenced code block" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "```\n/sem-approve\n```"}}' }

        it "returns true (fenced command is inert)" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "pr comment with sem-approve and trailing text" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "/sem-approve please rerun"}}' }

        it "returns true (unknown trailing tokens fail closed)" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "pr comment with unsupported command in multiline body" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "asd\r\n\r\n/sem-unknown"}}' }

        it "returns true" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "pr comment with sem-approve options" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "asd\r\n\r\n/sem-approve --include-secrets --enable-cache"}}' }

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end
      end

      context "pr comment with sem-approve options in reverse order" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "asd\r\n\r\n/sem-approve --enable-cache --include-secrets"}}' }

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end
      end

      context "pr comment with sem-approve options separated by tabs" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "asd\r\n\r\n/sem-approve\t--include-secrets"}}' }

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end
      end

      context "pr comment with multiple sem-approve options separated by tabs" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "asd\r\n\r\n/sem-approve\t--include-secrets\t--enable-cache"}}' }

        it "returns false" do
          expect(filter.unsupported_webhook?).to eql(false)
        end
      end

      context "pr comment with sem-approve options separated by punctuation" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "asd\r\n\r\n/sem-approve,--include-secrets"}}' }

        it "returns true" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "pr comment with sem-approve and unsupported option" do
        let(:payload) { '{"action": "created", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "/sem-approve --unsupported-option"}}' }

        it "returns true (unknown option fails closed)" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "edited pr comment with a valid command" do
        let(:payload) { '{"action": "edited", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "/sem-approve --include-secrets"}}' }

        it "returns true (edits do not approve)" do
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end

      context "deleted pr comment with a valid command" do
        let(:payload) { '{"action": "deleted", "issue": {"pull_request": {"url": ""}}, "comment": {"body": "/sem-approve"}}' }

        it "returns true (deletes do not approve)" do
          expect(filter.unsupported_webhook?).to eql(true)
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
