module InternalApi::RepoProxy
  class TagPayload
    def initialize(ref)
      @ref = ref
    end

    def call(project, user)
      repo_host = ::RepoHost::Factory.create_from_project(project)

      encoded_ref = CGI.escape(ref.delete_prefix("refs/tags/"))
      reference = repo_host.reference(project.repo_owner_and_name, "tags/#{encoded_ref}")

      tag_commit = repo_host.commit(project.repo_owner_and_name, commit_sha(reference, repo_host, project))

      repo_url = tag_commit[:html_url].split("/").first(5).join("/")
      author_name  = user.github_repo_host_account.name
      author_email = user.email
      github_uid = user.github_repo_host_account.github_uid
      avatar = ::Avatar.avatar_url(github_uid)

      commit = {
        "message" => tag_commit.commit.message,
        "id" => tag_commit.sha,
        "url" => tag_commit.html_url,
        "author" => {
          "name" => tag_commit.commit.author&.name || "",
          "email" => tag_commit.commit.author&.email || "",
          "username" => tag_commit.author&.login
        },
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

    attr_reader :ref

    def commit_sha(reference, repo_host, project)
      return reference[:object][:sha] if reference[:object][:type] == "commit"

      tag = repo_host.tag(project.repo_owner_and_name, reference[:object][:sha])
      tag[:object][:sha]
    end
  end
end
