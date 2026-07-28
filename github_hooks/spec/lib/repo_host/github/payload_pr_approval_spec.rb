require "spec_helper"

RSpec.describe RepoHost::Github::Payload do
  describe "PR approval commands" do
    # Builds an issue_comment payload. Defaults to a freshly *created* comment,
    # which is the only kind that may approve.
    def comment_payload(body:, action: "created", login: "octocat", uid: 4242)
      described_class.new(
        {
          "action" => action,
          "issue" => { "number" => 45, "pull_request" => { "url" => "https://example.test/pr/45" } },
          "comment" => {
            "body" => body,
            "id" => 7,
            "created_at" => "2026-07-20T00:00:00Z",
            "user" => { "login" => login, "id" => uid }
          }
        }.to_json
      )
    end

    it "recognizes /sem-approve as PR approval command" do
      payload = comment_payload(body: "/sem-approve")

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "recognizes /sem-approve --include-secrets option" do
      payload = comment_payload(body: "/sem-approve --include-secrets")

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "recognizes /sem-approve --enable-cache option" do
      payload = comment_payload(body: "/sem-approve --enable-cache")

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "accepts --include-cache as an alias for --enable-cache" do
      payload = comment_payload(body: "/sem-approve --include-cache")

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "recognizes /sem-approve with both include options" do
      payload = comment_payload(body: "/sem-approve --include-secrets --enable-cache")

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "recognizes /sem-approve with both include options in reverse order" do
      payload = comment_payload(body: "/sem-approve --enable-cache --include-secrets")

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "recognizes the --include-cache alias together with --include-secrets" do
      payload = comment_payload(body: "/sem-approve --include-secrets --include-cache")

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "recognizes options separated by tabs" do
      payload = comment_payload(body: "/sem-approve\t--include-secrets")

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "recognizes multiple options separated by tabs" do
      payload = comment_payload(body: "/sem-approve\t--include-secrets\t--enable-cache")

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "tolerates surrounding blank lines around the command" do
      payload = comment_payload(body: "\n/sem-approve --include-secrets\n")

      expect(payload.pr_approval?).to be(true)
      expect(payload.pr_approval_include_secrets?).to be(true)
    end

    # --- Security: the whole comment must be exactly the command ---

    it "does not recognize the command when any other line is present" do
      payload = comment_payload(body: "please review\n/sem-approve --include-secrets")

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
    end

    it "does not combine options across multiple command lines" do
      payload = comment_payload(body: "/sem-approve --include-secrets\n/sem-approve --enable-cache")

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "does not recognize an option spilled onto its own line" do
      payload = comment_payload(body: "/sem-approve --include-secrets\n--enable-cache")

      expect(payload.pr_approval?).to be(false)
    end

    it "does not recognize /sem-approve embedded in regular text" do
      payload = comment_payload(body: "LGTM /sem-approve")

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "does not recognize /sem-approve inside a blockquote (e.g. a quoted reply)" do
      payload = comment_payload(body: "> /sem-approve --include-secrets")

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
    end

    it "does not recognize /sem-approve inside inline code" do
      payload = comment_payload(body: "`/sem-approve`")

      expect(payload.pr_approval?).to be(false)
    end

    it "does not recognize /sem-approve inside a fenced code block" do
      payload = comment_payload(body: "```\n/sem-approve --include-secrets\n```")

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
    end

    it "does not recognize /sem-approve inside a four-backtick fence with a triple-backtick line" do
      payload = comment_payload(body: "````\n```\n/sem-approve --include-secrets\n````")

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
    end

    it "does not recognize /sem-approve inside an HTML comment (single line)" do
      payload = comment_payload(body: "<!-- /sem-approve --include-secrets -->")

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
    end

    it "does not recognize /sem-approve inside a multi-line HTML comment" do
      payload = comment_payload(body: "<!--\n/sem-approve --include-secrets\n-->")

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
    end

    it "does not recognize /sem-approve with trailing prose" do
      payload = comment_payload(body: "/sem-approve thanks")

      expect(payload.pr_approval?).to be(false)
    end

    it "does not recognize options separated by punctuation" do
      payload = comment_payload(body: "/sem-approve,--include-secrets")

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "fails closed when an unknown flag is present (does not silently approve)" do
      payload = comment_payload(body: "/sem-approve --include-secrets --unknown-flag")

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    it "does not treat unknown commands as approval command" do
      payload = comment_payload(body: "/sem-unknown")

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end

    # --- Security: only newly created comments may approve ---

    it "does not approve on an edited comment" do
      payload = comment_payload(body: "/sem-approve --include-secrets", action: "edited")

      expect(payload.comment_created?).to be(false)
      expect(payload.pr_approval?).to be(false)
    end

    it "does not approve on a deleted comment" do
      payload = comment_payload(body: "/sem-approve", action: "deleted")

      expect(payload.pr_approval?).to be(false)
    end

    it "reports comment_created? true for a created comment" do
      expect(comment_payload(body: "/sem-approve").comment_created?).to be(true)
    end

    # --- Identity ---

    it "exposes the immutable commenter uid" do
      expect(comment_payload(body: "/sem-approve", uid: 99001).comment_author_uid).to eq(99001)
    end

    it "exposes the commenter login" do
      expect(comment_payload(body: "/sem-approve", login: "maintainer").comment_author).to eq("maintainer")
    end

    # --- Persisted markers on the pull_request payload ---

    it "recognizes persisted enable option markers on pull request payload" do
      pr_payload = JSON.parse(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request)
      pr_payload["semaphore_approval_include_secrets"] = true
      pr_payload["semaphore_approval_enable_cache"] = true

      payload = described_class.new(pr_payload.to_json)

      expect(payload.pr_approval_include_secrets?).to be(true)
      expect(payload.pr_approval_enable_cache?).to be(true)
    end

    it "does not raise when comment body is missing" do
      payload = comment_payload(body: nil)

      expect(payload.pr_approval?).to be(false)
      expect(payload.pr_approval_include_secrets?).to be(false)
      expect(payload.pr_approval_enable_cache?).to be(false)
    end
  end
end
