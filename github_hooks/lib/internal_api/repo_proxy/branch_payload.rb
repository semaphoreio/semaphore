module InternalApi::RepoProxy
  class BranchPayload
    SHA_REGEXP = /\A[0-9a-f]{40}\z/

    def initialize(ref, sha)
      @ref = ref
      @sha = sha.to_s
    end

    def call(project, user)
      repo_host = ::RepoHost::Factory.create_from_project(project)
      repo = project.repo_owner_and_name

      # When the caller already supplied a fully-resolved 40-char SHA (the
      # common case for cron-driven periodic tasks), resolve everything with a
      # single `compare(base: sha, head: branch)` call instead of the separate
      # `reference` + `commit` pair:
      #
      #   * It still validates the branch exists, failing fast on typo'd/deleted
      #     branches. The head is the fully-qualified `refs/heads/<branch>` (the
      #     input `ref`) so GitHub resolves it strictly in the heads namespace —
      #     a *bare* ref follows git precedence (tags before heads), which would
      #     let a deleted branch validate against a same-named tag and build a
      #     phantom branch.
      #   * Its `base_commit` is the commit for `sha`, so we reuse it and skip
      #     the dedicated `commit` call.
      #
      # Net: one GitHub API call instead of two. The branch/SHA divergence
      # `status` is intentionally ignored — we only use `compare` for branch
      # existence + the commit object, matching the prior contract (which never
      # verified SHA-on-branch membership either).
      if SHA_REGEXP.match?(sha)
        response_ref = ref
        branch_commit = repo_host.compare(repo, sha, ref).base_commit
      else
        encoded_ref = CGI.escape(ref.delete_prefix("refs/heads/"))
        reference = repo_host.reference(repo, "heads/#{encoded_ref}")
        response_ref = reference.ref
        branch_commit = repo_host.commit(repo, commit_sha(sha, reference))
      end

      repo_url = branch_commit[:html_url].split("/").first(5).join("/")
      author_name  = user.github_repo_host_account.name
      author_email = user.email
      github_uid = user.github_repo_host_account.github_uid
      avatar = ::Avatar.avatar_url(github_uid)

      commit = {
        "message" => branch_commit.commit.message,
        "id" => branch_commit.sha,
        "url" => branch_commit.html_url,
        "author" => {
          "name" => branch_commit.commit.author&.name || "",
          "email" => branch_commit.commit.author&.email || "",
          "username" => branch_commit.author&.login
        },
        "timestamp" => ""
      }

      {
        "ref" => response_ref,
        "single" => true,
        "created" => true,
        "head_commit" => commit,
        "commits" => [commit],
        "after" => "",
        "before" => "",
        "repository" => {
          "html_url" => repo_url,
          "full_name" => repo
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
