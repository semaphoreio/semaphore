# frozen_string_literal: true

module RepoHost::Api
  class Payload
    def initialize(data)
      @data = data
    end

    def pull_request_name
      nil
    end

    def pull_request?
      false
    end
    alias_method :is_pull_request?, :pull_request?

    def draft_pull_request?
      false
    end

    def pull_request_ready_for_review?
      false
    end

    def pr_head_repo_name
      nil
    end

    def pr_head_sha
      nil
    end

    def pr_head_branch_name
      nil
    end

    def pr_base_branch_name
      nil
    end

    def pull_request_number
      0
    end

    def tag?
      ref.start_with?("refs/tags/")
    end

    def tag_name
      ref.delete_prefix("refs/tags/") if tag?
    end

    def branch_name
      if pull_request?
        "pull-request-#{pull_request_number}"
      else
        ref.delete_prefix("refs/heads/")
      end
    end

    def commit_message
      data.dig("commit", "message")
    end

    def commit_range
      "#{head}^...#{head}"
    end

    def commit_author
      data.dig("commit", "author_name")
    end

    def author_name
      data.dig("pusher", "name")
    end

    def author_email
      data.dig("pusher", "email")
    end

    def author_uid
      data.dig("commit", "author_uuid")
    end

    def author_avatar_url
      data.dig("commit", "author_avatar_url")
    end

    def repo_url
      data.dig("repository", "html_url")
    end

    def repo_name
      data.dig("repository", "full_name")
    end

    private

    attr_reader :data

    def head
      data.dig("commit", "sha")
    end

    def ref
      data.dig("reference")
    end
  end
end
