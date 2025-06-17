module RepoHost
  module Gitlab
    class Payload
      NULL_COMMIT = "0000000000000000000000000000000000000000".freeze

      def initialize(data)
        @data = data
      end

      def hook_type
        data["object_kind"]
      end

      def branch_action
        before = data["before"]
        after = data["after"]

        return "new" if before == NULL_COMMIT

        return "deleted" if after == NULL_COMMIT

        "push"
      end

      def pull_request_name
        data.dig("object_attributes", "title")
      end

      def pull_request?
        hook_type == "merge_request"
      end
      alias is_pull_request? pull_request?

      def is_draft_pull_request? # rubocop:disable Naming/PredicateName
        pull_request? && data.dig("object_attributes", "draft")
      end

      def pr_head_repo_name
        data.dig("object_attributes", "repository", "name")
      end

      def pr_head_sha
        data.dig("object_attributes", "last_commit", "id")
      end

      def pr_head_branch_name
        data.dig("object_attributes", "source", "branch")
      end

      def pr_base_branch_name
        data.dig("object_attributes", "target_branch")
      end

      def pull_request_number
        data.dig("object_attributes", "iid").to_i
      end

      def tag?
        hook_type == "tag_push"
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
        latest_commit["message"] || ""
      end

      def commit_range
        "#{head}^...#{head}"
      end

      def commit_author
        latest_commit.dig("author", "name") || ""
      end

      def commit_author_email
        latest_commit.dig("author", "email") || ""
      end

      def author_name
        data["user_username"] || ""
      end

      def author_email
        data["user_email"] || ""
      end

      def author_uid
        data["user_id"]&.to_s
      end

      def author_avatar_url
        data["user_avatar"] || ""
      end

      def repo_url
        data.dig("repository", "git_http_url") || ""
      end

      def repo_name
        data.dig("repository", "name") || ""
      end

      private

      attr_reader :data

      def head
        data["checkout_sha"] || data["after"]
      end

      def ref
        data["ref"] || ""
      end

      def latest_commit
        commits = data["commits"] || []
        commits.find { |commit| commit["id"] == head } || {}
      end
    end
  end
end
