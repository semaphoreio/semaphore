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

TagRef = Struct.new(:ref, :object) do
  def [](key)
    return ref    if key == :ref
    return object if key == :object

    nil
  end
end

RepoTagHostStub = Struct.new(:tag_commit) do
  def reference(*_args)
    TagRef.new("tags/v1.0.0", { sha: "abc123", type: "commit" })
  end

  def commit(*_args)
    tag_commit
  end

  def tag(_project, _ref)
    { object: { sha: "ghi789" } }
  end
end

RSpec.describe InternalApi::RepoProxy::TagPayload do
  let(:ref)     { "refs/tags/v1.0.0" }
  let(:project) { instance_double(Project, repo_owner_and_name: "owner/repo") }
  let(:user) do
    host_account = Struct.new(:name, :github_uid, :login)
                         .new("Alice", 123, "alice")
    Struct.new(:github_repo_host_account, :email)
          .new(host_account, "alice@example.com")
  end

  let(:tag_commit) do
    author      = GitAuthor.new("Alice", "alice@example.com", "alice")
    commit_data = GitCommitData.new("Tag commit", author)
    GitCommit.new(
      "abc123",
      "https://github.com/owner/repo/commit/abc123",
      commit_data,
      author
    )
  end

  let(:repo_host) { RepoTagHostStub.new(tag_commit) }

  before do
    allow(::RepoHost::Factory).to receive(:create_from_project).and_return(repo_host)
    allow(::Avatar).to receive(:avatar_url).and_return("http://avatar.url")
  end

  describe "#call" do
    subject(:payload) { described_class.new(ref).call(project, user) }

    it "returns a payload hash with expected keys" do
      expect(payload).to include(
        "ref" => "tags/v1.0.0",
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
      expect(commit["id"]).to eq("abc123")
      expect(commit["message"]).to eq("Tag commit")
    end
  end

  describe "#call with user without github connection" do
    subject(:payload) { described_class.new(ref).call(project, user_without_connection) }

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
    it "returns sha if type is commit" do
      obj = described_class.new(ref)
      result = obj.send(:commit_sha, TagRef.new(ref, { sha: "abc123", type: "commit" }), repo_host, project)
      expect(result).to eq("abc123")
    end

    it "returns tag object sha if type is not commit" do
      tag_ref = TagRef.new(ref, { sha: "def456", type: "tag" })
      obj = described_class.new(ref)
      result = obj.send(:commit_sha, tag_ref, repo_host, project)
      expect(result).to eq("ghi789")
    end
  end
end
