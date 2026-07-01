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

CompareResult = Struct.new(:base_commit) unless defined?(CompareResult)

RepoHostBranchStub = Struct.new(:branch_commit) do
  def reference(*_args)
    BranchRef.new("heads/main", { sha: branch_commit.sha, type: "commit" })
  end

  def commit(*_args)
    branch_commit
  end

  def compare(*_args)
    CompareResult.new(branch_commit)
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

  describe "#call when the caller already supplied a 40-char SHA" do
    # Pre-resolved SHAs come in from cron-driven periodic tasks etc. When
    # present, a single `compare(sha, branch)` call replaces the separate
    # `reference` + `commit` pair: it validates the branch still exists and
    # carries the commit object back as `base_commit`.
    let(:sha) { "a" * 40 }

    it "resolves via a single compare call against the fully-qualified branch ref" do
      # The head must be `refs/heads/<branch>`, not the bare name: a bare ref
      # would let GitHub resolve a same-named tag for a deleted branch.
      expect(repo_host).to receive(:compare)
        .with("owner/repo", sha, "refs/heads/main")
        .and_call_original
      expect(repo_host).not_to receive(:reference)
      expect(repo_host).not_to receive(:commit)
      described_class.new(ref, sha).call(project, user)
    end

    it "echoes the input ref into the payload" do
      payload = described_class.new(ref, sha).call(project, user)
      expect(payload["ref"]).to eq(ref)
    end

    it "builds the payload from the compared commit" do
      payload = described_class.new(ref, sha).call(project, user)
      expect(payload).to include(
        "ref" => ref,
        "single" => true,
        "created" => true,
        "head_commit" => a_kind_of(Hash),
        "commits" => [a_kind_of(Hash)]
      )
      expect(payload["commits"].last["id"]).to eq(sha)
    end

    it "wires author and commit details from base_commit (parity with the slow path)" do
      commit = described_class.new(ref, sha).call(project, user)["commits"].last
      expect(commit["author"]["name"]).to eq("Alice")
      expect(commit["author"]["email"]).to eq("alice@example.com")
      expect(commit["author"]["username"]).to eq("alice")
      expect(commit["id"]).to eq(sha)
      expect(commit["message"]).to eq("Branch commit")
    end

    it "fails fast when the branch no longer exists (does not swallow compare's 404)" do
      allow(repo_host).to receive(:compare).and_raise(RepoHost::RemoteException::NotFound)
      expect do
        described_class.new(ref, sha).call(project, user)
      end.to raise_error(RepoHost::RemoteException::NotFound)
    end
  end

  describe "#call when sha does not match SHA_REGEXP" do
    # Lock down the fall-through behavior: anything that isn't a lowercase
    # 40-char hex SHA goes through the slow path that calls `repo_host.reference`.
    # This documents and protects the current contract — in particular,
    # uppercase or mixed-case SHAs are NOT short-circuited.
    [
      ["empty string",        ""],
      ["nil (coerced to '')", nil],
      ["short hex",           "abc123"],
      ["uppercase 40-char",   "A" * 40],
      ["mixed-case 40-char",  "#{"a" * 39}B"],
      ["41 chars",            "a" * 41],
      ["non-hex 40-char",     "z" * 40]
    ].each do |label, bad_sha|
      it "falls through to repo_host.reference for #{label}" do
        expect(repo_host).to receive(:reference)
          .with("owner/repo", anything)
          .and_call_original
        described_class.new(ref, bad_sha).call(project, user)
      end
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
