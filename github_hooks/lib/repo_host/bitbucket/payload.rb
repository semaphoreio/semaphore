# frozen_string_literal: true

module RepoHost::Bitbucket
  class Payload
    attr_accessor :data, :branch, :commits, :head, :prev_head
    attr_reader :action

    ZERO_SHA = "0" * 40

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
      elsif tag?
        "refs/tags/#{tag_name}"
      else
        branch_ref = branch_name.presence || first_push_change.dig("old", "name")
        "refs/heads/#{branch_ref}"
      end
    end

    # ❌
    def pr_comment?
      pull_request? && @data["comment"].present?
    end

    # ❌
    def pr_approval?
      return false unless pr_comment?

      @data.dig("comment", "content", "raw").to_s.include?("/sem-approve")
    end

    # ❌
    def comment_author
      return nil unless pr_comment?

      @data.dig("comment", "user", "nickname")
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
        first_push_change["created"] && first_push_change.dig("new", "type") == "branch"
      end
    end

    # ❌
    def tag_created?
      first_push_change["created"] && first_push_change.dig("new", "type") == "tag"
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

    def pull_request_ready_for_review?
      false
    end

    # ❌
    def pull_request_within_repo?
      return false unless pull_request?

      source_repo = pull_request.dig("source", "repository", "full_name")
      destination_repo = pull_request.dig("destination", "repository", "full_name")

      return false if source_repo.blank? || destination_repo.blank?

      source_repo == destination_repo
    end

    # ❌
    def pull_request_forked_repo?
      return false unless pull_request?

      !pull_request_within_repo?
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
      %w[pullrequest:created pullrequest:reopened].include?(@action.to_s)
    end

    # ❌
    def pull_request_closed?
      %w[pullrequest:fulfilled pullrequest:rejected].include?(@action.to_s)
    end

    # ❌
    def pull_request_commit?
      %w[pullrequest:updated].include?(@action.to_s)
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
      pull_request.dig("links", "commits", "href") || ""
    end

    # ❌
    def pull_request_repo
      pull_request.dig("destination", "repository", "full_name") || ""
    end

    # ❌
    def repo_name
      if pull_request?
        pull_request_repo
      else
        @data.dig("repository", "full_name")
      end
    end

    # ❌
    def pr_head_repo_name
      pull_request.dig("source", "repository", "full_name") || ""
    end

    # ❌
    def pr_head_repo_owner
      pr_head_repo_name.to_s.split("/").first.to_s
    end

    # ❌
    def pr_head_branch_name
      pull_request.dig("source", "branch", "name") || ""
    end

    # ✔️
    def pr_base_branch_name
      pull_request.dig("destination", "branch", "name") || ""
    end

    # ✔️
    def pr_head_sha
      pull_request.dig("source", "commit", "hash") || ""
    end

    # ✔️
    def pr_base_sha
      pull_request.dig("destination", "commit", "hash") || ""
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
      return unless pull_request?

      @data["action"] ||
        @data["event"] ||
        @data["event_type"] ||
        @data["event_key"] ||
        @data["x-event-key"] ||
        @data.dig("headers", "X-Event-Key") ||
        @data.dig("headers", "x-event-key") ||
        @data.dig("headers", "HTTP_X_EVENT_KEY")
    end

    def extract_branch
      if pull_request?
        pull_request_branch_name
      elsif pr_comment?
        "pull-request-#{issue_number}"
      elsif tag?
        tag_name
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
      else
        first_push_change.dig("new", "target", "hash") ||
          first_push_change.dig("new", "hash") ||
          ZERO_SHA
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
