# frozen_string_literal: true

module RepoHost::Github
  class Payload
    attr_accessor :data, :branch, :commits, :head, :prev_head
    attr_reader :action

    PULL_REQUEST_OPENED = "opened"
    PULL_REQUEST_REOPENED = "reopened"
    PULL_REQUEST_CLOSED = "closed"
    PULL_REQUEST_COMMIT = "synchronize"

    def initialize(payload)
      @data = JSON.parse(payload)

      @branch = extract_branch
      @commits = extract_commits
      @head = extract_head
      @prev_head = extract_prev_head
      @action = extract_action
    end

    def ref
      if pull_request?
        "refs/pull/#{@data["number"]}/merge"
      elsif pr_comment?
        "refs/pull/#{issue_number}/merge"
      else
        @data["ref"]
      end
    end

    def pr_comment?
      @data["comment"] && @data["issue"] && @data["issue"]["pull_request"]
    end

    def pr_approval?
      return false unless pr_comment?

      @data["comment"]["body"].include?("/sem-approve")
    end

    def comment_author
      return nil unless pr_comment?

      @data["comment"]["user"]["login"]
    end

    def issue_number
      @data["issue"]["number"] if pr_comment?
    end

    def branch_created?
      if pull_request?
        pull_request_opened?
      else
        @data["created"] && @data["ref"].starts_with?("refs/heads/")
      end
    end

    def tag_created?
      @data["created"] && @data["ref"].starts_with?("refs/tags/")
    end

    def branch_deleted?
      if pull_request?
        pull_request_closed?
      else
        @data["deleted"]
      end
    end

    def force_pushed?
      @data["forced"]
    end

    def includes_ci_skip?
      return false if pull_request? || head_commit_message.nil?

      ::Semaphore::SkipCi.new.call(head_commit_message)
    end

    def head_commit_message
      if @commits.present? && @commits.last.present?
        @commits.last["message"]
      end
    end

    def commit_author
      if @commits.present? && @commits.last.present?
        @commits.last["author"]["username"]
      end
    end

    def commit_author_email
      if @commits.present? && @commits.last.present?
        @commits.last["author"]["email"]
      end
    end

    def commit_author_avatar
      github_avatar_from_username(commit_author)
    end

    def author_name
      if pull_request?
        @data.dig("sender", "login")
      elsif sent_by_bot_account?
        commit_author.presence || App.github_bot_name
      else
        @data.dig("pusher", "name")
      end
    end

    def author_email
      if sent_by_bot_account?
        commit_author_email.presence || ""
      else
        data.dig("pusher", "email")
      end
    end

    def author_avatar_url
      if sent_by_bot_account?
        commit_author_avatar.presence ||
          data.dig("sender", "avatar_url")
      else
        data.dig("sender", "avatar_url").presence ||
          github_avatar_from_username(data.dig("pusher", "name"))
      end
    end

    def sent_by_bot_account?
      @data.dig("pusher", "name") == App.github_bot_name
    end

    def pull_request?
      @data["pull_request"].present?
    end

    def draft_pull_request?
      pull_request? && (@data.dig("pull_request", "draft") == true)
    end

    def pull_request_within_repo?
      return false unless pull_request?

      return true unless head_contains_owner?

      head = payload_repo_label("head")
      base = payload_repo_label("base")

      head == base
    end

    def pull_request_forked_repo?
      return false unless pull_request?

      return false unless head_contains_owner?

      head = payload_repo_label("head")
      base = payload_repo_label("base")

      head != base
    end

    def tag?
      ref.start_with?("refs/tags/")
    end

    def tag_name
      ref.delete_prefix("refs/tags/") if tag?
    end

    def pull_request_opened?
      @action == PULL_REQUEST_OPENED || @action == PULL_REQUEST_REOPENED
    end

    def pull_request_closed?
      @action == PULL_REQUEST_CLOSED
    end

    def pull_request_commit?
      @action == PULL_REQUEST_COMMIT
    end

    def pull_request_number
      @data["number"] if pull_request?
    end

    def pull_request_name
      @data["pull_request"]["title"] if pull_request?
    end

    def pull_request_commits_url
      @data["pull_request"]["commits_url"] if pull_request?
    end

    def pull_request_repo
      @data["pull_request"]["base"]["repo"]["full_name"] if pull_request?
    end

    def repo_name
      if pull_request?
        @data.dig("pull_request", "base", "repo", "full_name")
      else
        @data.dig("repository", "full_name")
      end
    end

    def pr_head_repo_name
      @data.dig("pull_request", "head", "repo", "full_name")
    end

    def pr_head_repo_owner
      @data.dig("pull_request", "head", "repo", "owner", "login")
    end

    def pr_head_branch_name
      @data.dig("pull_request", "head", "ref")
    end

    def pr_base_branch_name
      @data.dig("pull_request", "base", "ref")
    end

    def pr_head_sha
      @data.dig("pull_request", "head", "sha")
    end

    def pr_base_sha
      @data.dig("pull_request", "base", "sha")
    end

    def repo_url
      @data.dig("repository", "html_url")
    end

    def author_uid
      @data.dig("sender", "id")
    end

    def branch_name
      @branch
    end

    def name
      head_commit_message
    end

    def commit_message
      head_commit_message
    end

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
          if @data["commits"].empty? and branch_created?
            "#{head}^...#{head}"
          elsif @data["commits"].empty?
            ""
          else
            "#{commits.first["id"]}^...#{head}"
          end
        elsif force_pushed?
          if @data["commits"].empty?
            "#{prev_head}...#{head}"
          else
            "#{commits.first["id"]}^...#{head}"
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
        @data["action"]
      else
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
        ref.delete_prefix("refs/heads/")
      end
    end

    def extract_commits
      unless pull_request?
        extract_commits_from_push
      end
    end

    def extract_commits_from_push
      pushed_commits = @data["commits"]

      if branch_deleted?
        pushed_commits
      else
        pushed_commits.presence || [@data["head_commit"]]
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
        @data["before"]
      end
    end

    def pull_request_branch_name
      "pull-request-#{pull_request_number}"
    end

    # unexpected payload from GH
    # GH always sends owner:branch until feb 19
    def head_contains_owner?
      @data["pull_request"]["head"]["label"].include?(":")
    end

    def payload_repo_label(repo)
      @data["pull_request"][repo]["label"].split(":").first
    end

    def github_avatar_from_username(username)
      return nil unless username.present?

      "https://avatars.githubusercontent.com/#{username}?v=4"
    end
  end
end
