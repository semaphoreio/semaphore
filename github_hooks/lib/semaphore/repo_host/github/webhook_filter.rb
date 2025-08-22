module Semaphore::RepoHost::Github

  class WebhookFilter

    MEMBER_GITHUB_WEBHOOK_EVENT = ["member", "membership", "team"]
    GITHUB_APP_WEBHOOK_EVENTS = ["installation", "installation_repositories"]
    SUPPORTED_GITHUB_WEBHOOK_EVENTS = ["push", "pull_request", "member", "issue_comment", "installation", "installation_repositories", "team", "membership", "repository"]
    SUPPORTED_GITHUB_PULL_REQUEST_ACTIONS = ["opened", "synchronize", "closed", "reopened", "ready_for_review"]
    SUPPORTED_PR_COMMANDS = ["/sem-approve"]

    def initialize(request, payload)
      @request = request
      @payload = payload
    end

    def unsupported_webhook?
      !supported_webhook?
    end

    def unavailable_payload?
      @payload.blank?
    end

    def member_webhook?
      MEMBER_GITHUB_WEBHOOK_EVENT.include?(webhook_event)
    end

    def github_app_installation_webhook?
      GITHUB_APP_WEBHOOK_EVENTS.include?(webhook_event)
    end

    def github_app_webhook?
      installation_target_type == "integration"
    end

    def repository_webhook?
      webhook_event == "repository"
    end

    def repository
      payload_data["repository"]
    end

    def installation_id
      payload_data.dig("installation", "id")
    end

    private

    def supported_webhook?
      supported_webhook_event? &&
        supported_webhook_action? &&
        supported_webhook_command? &&
        supported_webhook_membership_scope? &&
        supported_webhook_team_action?
    end

    def supported_webhook_event?
      SUPPORTED_GITHUB_WEBHOOK_EVENTS.include?(webhook_event)
    end

    def supported_webhook_action?
      !pull_request? || supported_pull_request_action?
    end

    def supported_webhook_command?
      !issue_comment? || supported_pr_command?
    end

    def supported_webhook_membership_scope?
      !membership? || supported_membership_scope?
    end

    def supported_webhook_team_action?
      !team? || supported_team_action?
    end

    def supported_pull_request_action?
      SUPPORTED_GITHUB_PULL_REQUEST_ACTIONS.include?(webhook_action)
    end

    def supported_pr_command?
      payload_data["issue"]["pull_request"].present? &&
        SUPPORTED_PR_COMMANDS.any? { |cmd| pull_request_command.include?(cmd) }
    end

    def supported_membership_scope?
      payload_data["scope"] == "team"
    end

    def supported_team_action?
      payload_data["action"] != "edited" || payload_data["changes"]["repository"].present?
    end

    def pull_request?
      webhook_event == "pull_request"
    end

    def issue_comment?
      webhook_event == "issue_comment"
    end

    def membership?
      webhook_event == "membership"
    end

    def team?
      webhook_event == "team"
    end

    def webhook_event
      @request.raw_request.headers["X-Github-Event"]
    end

    def installation_target_type
      @request.raw_request.headers["X-GitHub-Hook-Installation-Target-Type"]
    end

    def webhook_action
      payload_data["action"]
    end

    def pull_request_command
      payload_data["comment"]["body"]
    end

    def payload_data
      @payload_data ||= JSON.parse(@payload)
    end
  end
end
