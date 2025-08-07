# frozen_string_literal: true

module RepoHost::Git
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
    alias is_pull_request? pull_request?

    def is_draft_pull_request? # rubocop:disable Naming/PredicateName
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
      data.dig("author", "name")
    end

    def author_name
      data.dig("author", "name")
    end

    def author_email
      data.dig("author", "email")
    end

    def author_uid
      nil
    end

    def author_avatar_url
      ""
    end

    def repo_url
      ""
    end

    def repo_name
      ""
    end

    private

    attr_reader :data

    def head
      data.dig("commit", "sha")
    end

    def ref
      data["reference"]
    end
  end
end
