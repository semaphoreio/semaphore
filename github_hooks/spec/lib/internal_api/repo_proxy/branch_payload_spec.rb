require "spec_helper"

GitAuthor = Struct.new(:name, :email, :login) unless defined?(GitAuthor)
GitCommitData = Struct.new(:message, :author) unless defined?(GitCommitData)
unless defined?(GitCommit)
  GitCommit = Struct.new(:sha, :html_url, :commit, :author) do
    def [](key)
      html_url if key == :html_url
    end
  end
end

BranchRef = Struct.new(:ref, :object) do
  def [](key)
    return ref    if key == :ref
    return object if key == :object

    nil
  end
end

RepoHostBranchStub = Struct.new(:branch_commit) do
  def reference(*_args)
    BranchRef.new("heads/main", { sha: branch_commit.sha, type: "commit" })
  end

  def commit(*_args)
    branch_commit
  end
end

RSpec.describe InternalApi::RepoProxy::BranchPayload do
  let(:ref)    { "refs/heads/main" }
  let(:sha)    { "abc123" }
  let(:project) { instance_double(Project, repo_owner_and_name: "owner/repo") }
  let(:user) do
    host_account = Struct.new(:name, :github_uid, :login)
                         .new("Alice", 123, "alice")
    Struct.new(:github_repo_host_account, :email)
          .new(host_account, "alice@example.com")
  end

  let(:branch_commit) do
    author      = GitAuthor.new("Alice", "alice@example.com", "alice")
    commit_data = GitCommitData.new("Branch commit", author)
    GitCommit.new(
      sha,
      "https://github.com/owner/repo/commit/#{sha}",
      commit_data,
      author
    )
  end

  let(:repo_host) { RepoHostBranchStub.new(branch_commit) }

  before do
    allow(::RepoHost::Factory).to receive(:create_from_project).and_return(repo_host)
    allow(::Avatar).to receive(:avatar_url).and_return("http://avatar.url")
  end

  describe "#call" do
    subject(:payload) { described_class.new(ref, sha).call(project, user) }

    it "returns a payload hash with expected keys" do
      expect(payload).to include(
        "ref" => "heads/main",
        "single" => true,
        "created" => true,
        "head_commit" => a_kind_of(Hash),
        "commits" => [a_kind_of(Hash)],
        "repository" => hash_including("html_url", "full_name"),
        "pusher" => hash_including("name", "email"),
        "sender" => hash_including("id", "avatar_url")
      )
    end

    it "sets author and commit details correctly" do
      commit = payload["commits"].last
      expect(commit["author"]["name"]).to eq("Alice")
      expect(commit["author"]["email"]).to eq("alice@example.com")
      expect(commit["author"]["username"]).to eq("alice")
      expect(commit["id"]).to eq(sha)
      expect(commit["message"]).to eq("Branch commit")
    end
  end

  describe "#call with user without github connection" do
    subject(:payload) { described_class.new(ref, sha).call(project, user_without_connection) }

    let(:synthetic_account) do
      Struct.new(:name, :github_uid, :login)
            .new("Bob", "12345678", "12345678")
    end
    let(:user_without_connection) do
      Struct.new(:github_repo_host_account, :email)
            .new(synthetic_account, "bob@example.com")
    end

    it "returns a payload hash with synthetic user data" do
      expect(payload["pusher"]["name"]).to eq("Bob")
      expect(payload["pusher"]["email"]).to eq("bob@example.com")
      expect(payload["sender"]["id"]).to eq("12345678")
    end
  end

  describe "#commit_sha" do
    it "returns sha if it matches SHA_REGEXP" do
      obj = described_class.new(ref, sha)
      result = obj.send(:commit_sha, sha, BranchRef.new("heads/main", { sha: sha, type: "commit" }))
      expect(result).to eq(sha)
    end

    it "returns reference sha if type is commit and sha is not valid" do
      bad_sha = "notasha"
      ref_obj = { ref: "heads/main", object: { sha: "def456", type: "commit" } }
      obj = described_class.new(ref, bad_sha)
      result = obj.send(:commit_sha, bad_sha, ref_obj)
      expect(result).to eq("def456")
    end

    it "returns nil if neither condition matches" do
      bad_sha = "notasha"
      ref_obj = { ref: "heads/main", object: { sha: "def456", type: "tag" } }
      obj = described_class.new(ref, bad_sha)
      result = obj.send(:commit_sha, bad_sha, ref_obj)
      expect(result).to be_nil
    end
  end
end
