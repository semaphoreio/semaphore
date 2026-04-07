require "spec_helper"

RSpec.describe RepoHost::Github::Payload do
  describe "PR approval commands" do
    it "recognizes /sem-approve as PR approval command" do
      payload = described_class.new(
        {
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => { "body" => "/sem-approve", "user" => { "login" => "octocat" } }
        }.to_json
      )

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "recognizes /sem-approve --include-secrets option" do
      payload = described_class.new(
        {
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => { "body" => "/sem-approve --include-secrets", "user" => { "login" => "octocat" } }
        }.to_json
      )

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "recognizes /sem-approve --enable-cache option" do
      payload = described_class.new(
        {
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => { "body" => "/sem-approve --enable-cache", "user" => { "login" => "octocat" } }
        }.to_json
      )

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "recognizes /sem-approve with both include options" do
      payload = described_class.new(
        {
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => { "body" => "/sem-approve --include-secrets --enable-cache", "user" => { "login" => "octocat" } }
        }.to_json
      )

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "recognizes /sem-approve with both include options in reverse order" do
      payload = described_class.new(
        {
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => { "body" => "/sem-approve --enable-cache --include-secrets", "user" => { "login" => "octocat" } }
        }.to_json
      )

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "recognizes options separated by tabs" do
      payload = described_class.new(
        {
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => { "body" => "/sem-approve\t--include-secrets", "user" => { "login" => "octocat" } }
        }.to_json
      )

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "recognizes multiple options separated by tabs" do
      payload = described_class.new(
        {
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => { "body" => "/sem-approve\t--include-secrets\t--enable-cache", "user" => { "login" => "octocat" } }
        }.to_json
      )

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "does not recognize options separated by punctuation" do
      payload = described_class.new(
        {
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => { "body" => "/sem-approve,--include-secrets", "user" => { "login" => "octocat" } }
        }.to_json
      )

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "recognizes only options that stay on the same line as /sem-approve" do
      payload = described_class.new(
        {
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => { "body" => "/sem-approve --include-secrets\n--enable-cache", "user" => { "login" => "octocat" } }
        }.to_json
      )

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "does not treat unknown commands as approval command" do
      payload = described_class.new(
        {
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => { "body" => "/sem-unknown", "user" => { "login" => "octocat" } }
        }.to_json
      )

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "recognizes persisted enable option markers on pull request payload" do
      pr_payload = JSON.parse(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request)
      pr_payload["semaphore_approval_include_secrets"] = true
      pr_payload["semaphore_approval_enable_cache"] = true

      payload = described_class.new(pr_payload.to_json)

      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "does not raise when comment body is missing" do
      payload = described_class.new(
        {
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => { "body" => nil, "user" => { "login" => "octocat" } }
        }.to_json
      )

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end
  end
end
