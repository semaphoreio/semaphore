module InternalApi::RepoProxy
  class PrPayload
    include UserInfo

    class PrNotMergeableError < StandardError; end

    def initialize(ref, number)
      @ref = ref
      @number = number
    end

    def call(project, user)
      state, meta, msg = Semaphore::RepoHost::Hooks::Handler.update_pr_data(project, number, nil, false)
      pr = meta[:pr]

      if state == :not_found
        raise PrNotMergeableError, "Pull Request ##{number} was not found: #{msg}"
      end

      if state == :non_mergeable
        raise PrNotMergeableError, "Pull Request ##{number} is not mergeable (#{pr[:html_url]})"
      end

      repo_host = ::RepoHost::Factory.create_from_project(project)
      pr_commit = repo_host.commit(project.repo_owner_and_name, pr[:head][:sha])

      commit = {
        "message" => pr_commit.commit.message,
        "id" => pr_commit.sha,
        "url" => pr_commit.html_url,
        "author" => {
          "name" => pr_commit.commit.author&.name || "",
          "email" => pr_commit.commit.author&.email || "",
          "username" => pr_commit.author&.login
        },
        "timestamp" => ""
      }

      repo_url = pr[:html_url].split("/").first(5).join("/")
      author_name, author_email, github_uid, avatar, login = user_info(user)

      {
        "semaphore_ref" => meta[:ref],
        "merge_commit_sha" => meta[:merge_commit_sha],
        "commit_author" => meta[:commit_author],
        "action" => pr["state"],
        "ref" => meta[:ref],
        "number" => pr["number"],
        "pull_request" => {
          "title" => pr["title"],
          "commits_url" => pr["commits_url"],
          "base" => pr["base"].to_h,
          "head" => pr["head"].to_h
        },
        "commits" => [commit],
        "single" => true,
        "created" => true,
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
          "avatar_url" => avatar,
          "login" => login.presence || author_name
        }
      }
    end

    private

    attr_reader :ref, :number

  end
end
