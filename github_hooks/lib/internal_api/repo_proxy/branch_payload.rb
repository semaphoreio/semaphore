module InternalApi::RepoProxy
  class BranchPayload
    SHA_REGEXP = /\A[0-9a-f]{40}\z/

    def initialize(ref, sha)
      @ref = ref
      @sha = sha.to_s
    end

    def call(project, user)
      repo_host = ::RepoHost::Factory.create_from_project(project)

      reference = repo_host.reference(project.repo_owner_and_name, ref.delete_prefix("refs/"))

      commit = repo_host.commit(project.repo_owner_and_name, commit_sha(sha, reference))

      repo_url = commit[:html_url].split("/").first(5).join("/")
      author_name  = user.github_repo_host_account.name
      author_email = user.email
      github_uid = user.github_repo_host_account.github_uid
      avatar = ::Avatar.avatar_url(github_uid)

      commit = {
        "message" => commit.commit.message,
        "id" => commit.sha,
        "url" => commit.html_url,
        "author" => { "name" => "", "email" => "" },
        "timestamp" => ""
      }

      {
        "ref" => reference.ref,
        "single" => true,
        "created" => true,
        "head_commit" => commit,
        "commits" => [commit],
        "after" => "",
        "before" => "",
        "repository" => {
          "html_url" => repo_url,
          "full_name" => project.repo_owner_and_name
        },
        "pusher" => {
          "name" => author_name,
          "email" => author_email
        },
        "sender" => {
          "id" => github_uid,
          "avatar_url" => avatar
        }
      }
    end

    private

    attr_reader :ref, :sha

    def commit_sha(sha, reference)
      return sha if SHA_REGEXP.match?(sha)
      return reference[:object][:sha] if reference[:object][:type] == "commit"

      nil
    end
  end
end
