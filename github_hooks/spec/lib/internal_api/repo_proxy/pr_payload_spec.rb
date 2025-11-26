require "spec_helper"

GitAuthor = Struct.new(:name, :email, :login)
GitCommitData = Struct.new(:message, :author)
GitCommit = Struct.new(:sha, :html_url, :commit, :author) do
  def [](key)
    html_url if key == :html_url
  end
end

RepoHostStub = Struct.new(:pr_commit) do
  def commit(*_args)
    pr_commit
  end
end

RSpec.describe InternalApi::RepoProxy::PrPayload do
  let(:ref)      { "refs/pull/1/head" }
  let(:number)   { 1 }
  let(:project)  { instance_double(Project, repo_owner_and_name: "owner/repo") }
  let(:user) do
    host_account = Struct.new(:name, :github_uid, :login).new("Alice", 123, "alice")
    Struct.new(:github_repo_host_account, :email, :name)
          .new(host_account, "alice@example.com", "Alice")
  end

  let(:pr_commit) do
    author      = GitAuthor.new("Alice", "alice@example.com", "alice")
    commit_data = GitCommitData.new("PR commit", author)
    GitCommit.new(
      "abc123",
      "https://github.com/owner/repo/commit/abc123",
      commit_data,
      author
    )
  end

  let(:repo_host) { RepoHostStub.new(pr_commit) }

  let(:pr) do
    {
      "number" => 1,
      head: { sha: "abc123", ref: "feature-branch", repo: { full_name: "owner/repo" } },
      base: { ref: "main", repo: { full_name: "owner/repo" } },
      title: "A PR",
      commits_url: "https://api.github.com/repos/owner/repo/pulls/1/commits",
      html_url: "https://github.com/owner/repo/pull/1"
    }
  end
  let(:meta) { { pr: pr, ref: ref, merge_commit_sha: "abc123", commit_author: "Alice" } }

  before do
    allow(::RepoHost::Factory).to receive(:create_from_project).and_return(repo_host)
    allow(::Avatar).to receive(:avatar_url).and_return("http://avatar.url")
  end

  describe "#call" do
    subject(:payload) { described_class.new(ref, number).call(project, user) }

    before do
      allow(Semaphore::RepoHost::Hooks::Handler)
        .to receive(:update_pr_data)
        .and_return([:ok, meta, ""])
    end

    it "returns a payload hash with expected keys" do
      expect(payload).to include(
        "number" => 1,
        "pull_request" => a_kind_of(Hash),
        "commits" => [a_kind_of(Hash)],
        "repository" => hash_including("html_url", "full_name"),
        "pusher" => hash_including("name", "email"),
        "sender" => hash_including("id", "avatar_url", "login")
      )
    end

    it "sets author and commit details correctly" do
      commit = payload["commits"].last
      expect(commit["author"]["name"]).to eq("Alice")
      expect(commit["author"]["email"]).to eq("alice@example.com")
      expect(commit["author"]["username"]).to eq("alice")
      expect(commit["id"]).to eq("abc123")
      expect(commit["message"]).to eq("PR commit")
    end

    context "when user has no repo host account" do
      subject(:payload_without_account) { described_class.new(ref, number).call(project, user_without_repo_host_account) }

      let(:user_without_repo_host_account) do
        Struct.new(:github_repo_host_account, :email, :name)
              .new(nil, "alice@example.com", "Alice")
      end

      it "uses the user's name and email for pusher data" do
        expect(payload_without_account["pusher"]["name"]).to eq("Alice")
        expect(payload_without_account["pusher"]["email"]).to eq("alice@example.com")
        expect(payload_without_account["sender"]["id"]).to be_nil
        expect(payload_without_account["sender"]["login"]).to eq("Alice")
      end
    end
  end

  context "when PR is not found" do
    before do
      allow(Semaphore::RepoHost::Hooks::Handler)
        .to receive(:update_pr_data)
        .and_return([:not_found, {}, "not found"])
    end

    it "raises PrNotMergeableError" do
      expect do
        described_class.new(ref, number).call(project, user)
      end.to raise_error(described_class::PrNotMergeableError, /not found/i)
    end
  end

  context "when PR is not mergeable" do
    before do
      allow(Semaphore::RepoHost::Hooks::Handler)
        .to receive(:update_pr_data)
        .and_return([:non_mergeable, { pr: pr }, "not mergeable"])
    end

    it "raises PrNotMergeableError" do
      expect do
        described_class.new(ref, number).call(project, user)
      end.to raise_error(described_class::PrNotMergeableError, /not mergeable/i)
    end
  end
end
