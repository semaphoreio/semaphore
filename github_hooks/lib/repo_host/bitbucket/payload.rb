# frozen_string_literal: true

module RepoHost::Bitbucket
  class Payload
    attr_accessor :data, :branch, :commits, :head, :prev_head
    attr_reader :action

    PULL_REQUEST_OPENED = "opened"
    PULL_REQUEST_REOPENED = "reopened"
    PULL_REQUEST_CLOSED = "closed"
    PULL_REQUEST_COMMIT = "synchronize"

    def initialize(data)
      @data = data

      @branch = extract_branch
      @commits = extract_commits
      @head = extract_head
      @prev_head = extract_prev_head
      @action = extract_action
    end

    # ✔️
    def ref
      if pull_request?
        "refs/pull/#{pull_request_number}/merge"
      else
        "refs/head/#{pull_request_name}"
      end
    end

    # ❌
    def pr_comment?
      @data["comment"] && @data["issue"] && @data["issue"]["pull_request"]
    end

    # ❌
    def pr_approval?
      return false unless pr_comment?

      @data["comment"]["body"].include?("/sem-approve")
    end

    # ❌
    def comment_author
      return nil unless pr_comment?

      @data["comment"]["user"]["login"]
    end

    # ✔️
    def issue_number
      pull_request_number if pr_comment?
    end

    # ❌
    def branch_created?
      if pull_request?
        pull_request_opened?
      else
        @data["created"] && @data["ref"].starts_with?("refs/heads/")
      end
    end

    # ❌
    def tag_created?
      @data["created"] && @data["ref"].starts_with?("refs/tags/")
    end

    # ✔️
    def branch_deleted?
      if pull_request?
        pull_request_closed?
      else
        first_push_change["closed"]
      end
    end

    # ✔️
    def force_pushed?
      first_push_change["forced"]
    end

    # ✔️
    def includes_ci_skip?
      return false if pull_request? || head_commit_message.nil?

      ::Semaphore::SkipCi.new.call(head_commit_message)
    end

    # ✔️
    def head_commit_message
      if @commits.present? && @commits.last.present?
        @commits.last["message"]
      end
    end

    # ✔️
    def commit_author
      @commits.last&.dig("author", "user", "nickname") || ""
    end

    # ✔️
    def commit_author_email
      if @commits.present? && @commits.last.present?
        @commits.last["author"]["raw"]
      end
    end

    # ✔️
    def commit_author_avatar
      if @commits.present? && @commits.last.present?
        @commits.last["author"]["user"]["links"]["avatar"]["href"]
      end
    end

    # ✔️
    def author_email
      ""
    end

    # ✔️
    def author_name
      @data.dig("actor", "nickname") || @data.dig("actor", "username") || ""
    end

    # ✔️
    def author_uid
      @data.dig("actor", "uuid") || ""
    end

    # ✔️
    # TODO: check other actors
    def author_avatar_url
      @data.dig("actor", "links", "avatar", "href")
    end

    # ✔️
    def pull_request?
      @data["pullrequest"].present?
    end

    # ✔️
    def repo_url
      @data.dig("repository", "links", "html", "href")
    end

    def draft_pull_request?
      false
    end

    # ❌
    def pull_request_within_repo?
      return false unless pull_request?

      return true unless head_contains_owner?

      head = payload_repo_label("head")
      base = payload_repo_label("base")

      head == base
    end

    # ❌
    def pull_request_forked_repo?
      return false unless pull_request?

      return false unless head_contains_owner?

      head = payload_repo_label("head")
      base = payload_repo_label("base")

      head != base
    end

    # ✔️
    def tag?
      first_push_change.dig("new", "type") == "tag"
    end

    # ✔️
    def tag_name
      first_push_change.dig("new", "name")
    end

    # ❌
    def pull_request_opened?
      @action == PULL_REQUEST_OPENED || @action == PULL_REQUEST_REOPENED
    end

    # ❌
    def pull_request_closed?
      @action == PULL_REQUEST_CLOSED
    end

    # ❌
    def pull_request_commit?
      @action == PULL_REQUEST_COMMIT
    end

    # ✔️
    def pull_request_number
      pull_request["id"] || ""
    end

    # ✔️
    def pull_request_name
      pull_request["title"] || ""
    end

    # ❌
    def pull_request_commits_url
      @data.dig("pullrequest", "commits_url") || ""
    end

    # ❌
    def pull_request_repo
      @data.dig("pullrequest", "base", "repo", "full_name") || ""
    end

    # ❌
    def repo_name
      if pull_request?
        @data.dig("pullrequest", "base", "repo", "full_name")
      else
        @data.dig("repository", "full_name")
      end
    end

    # ❌
    def pr_head_repo_name
      @data.dig("pull_request", "head", "repo", "full_name") || ""
    end

    # ❌
    def pr_head_repo_owner
      @data.dig("pull_request", "head", "repo", "owner", "login") || ""
    end

    # ❌
    def pr_head_branch_name
      @data.dig("pull_request", "head", "ref") || ""
    end

    # ✔️
    def pr_base_branch_name
      pull_request.dig("destination", "branch", "name") || ""
    end

    # ✔️
    def pr_head_sha
      pull_request.dig("destination", "commit", "hash") || ""
    end

    # ✔️
    def pr_base_sha
      pull_request.dig("source", "commit", "hash") || ""
    end

    # ✔️
    def name
      head_commit_message
    end

    # ✔️
    def branch_name
      @branch
    end

    # ✔️
    def commit_message
      if tag?
        first_push_change.dig("new", "target", "message")
      else
        head_commit_message
      end
    end

    # ✔️
    def commit_range
      if single?
        "#{head}^...#{head}"
      elsif branch_deleted?
        ""
      elsif pull_request?
        "#{pr_base_sha}...#{pr_head_sha}"
      elsif tag?
        ""
      else
        if prev_head == "0000000000000000000000000000000000000000"
          if commits.empty? and branch_created?
            "#{head}^...#{head}"
          elsif commits.empty?
            ""
          else
            "#{commits.first["hash"]}^...#{head}"
          end
        elsif force_pushed?
          if commits.empty?
            "#{prev_head}...#{head}"
          else
            "#{commits.first["hash"]}^...#{head}"
          end
        else
          "#{prev_head}...#{head}"
        end
      end
    end

    private

    def single?
      @data["single"] == true
    end

    def extract_action
      if pull_request?
        "undefined"
      end
    end

    def extract_branch
      if pull_request?
        pull_request_branch_name
      elsif pr_comment?
        "pull-request-#{issue_number}"
      elsif tag?
        # tag_name
        # tmp revert of changes
        # https://github.com/renderedtext/issues/issues/2172
        ref.delete_prefix("refs/heads/")
      else
        first_push_change.dig("new", "name")
      end
    end

    # ✔️
    def extract_commits
      unless pull_request?
        extract_commits_from_push
      end
    end

    # ✔️
    def extract_commits_from_push
      pushed_commits = first_push_change.dig("commits") || []

      if branch_deleted?
        [first_push_change]
      else
        pushed_commits.sort_by { |c| c["date"] }
      end
    end

    def extract_head
      if pull_request?
        pr_head_sha
      elsif @data["head_commit"]
        # If head commit exists, use that one to extract the commit.
        # The distinction between "head_commit" and "after" is important in
        # case of annotated tags.
        #
        # In almost every case, we want to use head commits. If this field is
        # missing (not sure how or why?) than we will fallback to "after".

        @data["head_commit"]["id"]
      else
        @data["after"]
      end
    end

    def extract_prev_head
      if pull_request?
        "0000000000000000000000000000000000000000"
      else
        first_push_change.dig("old", "target", "hash")
      end
    end

    def pull_request_branch_name
      "pull-request-#{pull_request_number}"
    end

    # # unexpected payload from GH
    # # GH always sends owner:branch until feb 19
    def head_contains_owner?
      @data["pull_request"]["head"]["label"].include?(":")
    end

    def payload_repo_label(repo)
      @data["pull_request"][repo]["label"].split(":").first
    end

    def first_push_change
      @data.dig("push", "changes")&.first || {}
    end

    def pull_request
      @data.dig("pullrequest") || {}
    end

    def head_commit
      pull_request.dig("destination", "commit")
    end

    # def first_commit
    #   @data.dig(
    # end
  end
end
