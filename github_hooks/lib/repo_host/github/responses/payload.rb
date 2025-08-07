# encoding: UTF-8

module RepoHost::Github::Responses::Payload
  module_function

  def pull_request_labeled
    get_payload("fixtures/github_payloads/pull_request_labeled.json")
  end

  def pull_request_assigned
    get_payload("fixtures/github_payloads/pull_request_assigned.json")
  end

  def pull_request_commits
    get_payload("fixtures/github_payloads/pull_request_commits.json")
  end

  def post_receive_hook_pull_request_commit
    get_payload("fixtures/github_payloads/post_receive_hook_pull_request_commit.json")
  end

  def post_receive_hook_pull_request_closed
    get_payload("fixtures/github_payloads/post_receive_hook_pull_request_closed.json")
  end

  def post_receive_draft_hook_pull_request
    get_payload("fixtures/github_payloads/post_receive_hook_pull_request_draft.json")
  end

  def post_receive_hook_pull_request
    get_payload("fixtures/github_payloads/post_receive_hook_pull_request.json")
  end

  def post_receive_hook_pull_request_within_repo
    get_payload("fixtures/github_payloads/post_receive_hook_pull_request_within_repo.json")
  end

  def post_receive_hook_member
    get_payload("fixtures/github_payloads/post_receive_hook_member.json")
  end

  def post_receive_hook
    get_payload("fixtures/github_payloads/post_receive_hook.json")
  end

  def post_receive_hook_on_created_branch
    get_payload("fixtures/github_payloads/post_receive_hook_on_created_branch.json")
  end

  def post_receive_hook_on_deleted_branch
    get_payload("fixtures/github_payloads/post_receive_hook_on_deleted_branch.json")
  end

  def post_receive_hook_on_created_tag
    get_payload("fixtures/github_payloads/post_receive_hook_on_created_tag.json")
  end

  def with_ci_skip
    get_payload("fixtures/github_payloads/with_ci_skip.json")
  end

  def with_skip_ci
    get_payload("fixtures/github_payloads/with_skip_ci.json")
  end

  def without_commits_hook
    get_payload("fixtures/github_payloads/without_commits.json")
  end

  def post_receive_hook_with_force_pushed_branch
    get_payload("fixtures/github_payloads/post_receive_hook_with_force_pushed_branch.json")
  end

  def webhook_json
    get_payload("fixtures/github_payloads/webhook_json.json")
  end

  def asian_post_receive_hook
    get_payload("fixtures/github_payloads/asian_post_receive_hook.json")
  end

  def post_receive_hook_issue_comment
    get_payload("fixtures/github_payloads/issue_comment_hook.json")
  end

  def repository_renamed_hook
    get_payload("fixtures/github_payloads/repostitory_renamed.json")
  end

  def repository_renamed_app_hook
    get_payload("fixtures/github_payloads/repostitory_renamed_app.json")
  end

  def default_branch_changed
    get_payload("fixtures/github_payloads/default_branch_changed.json")
  end

  def installation_created
    get_payload("fixtures/github_payloads/post_receive_hook_installation_created.json")
  end

  def installation_deleted
    get_payload("fixtures/github_payloads/post_receive_hook_installation_deleted.json")
  end

  def installation_suspended
    get_payload("fixtures/github_payloads/post_receive_hook_installation_suspended.json")
  end

  def installation_unsuspended
    get_payload("fixtures/github_payloads/post_receive_hook_installation_unsuspended.json")
  end

  def installation_new_permissions_accepted
    get_payload("fixtures/github_payloads/post_receive_hook_installation_new_permission_accepted.json")
  end

  def installation_repositories_added
    get_payload("fixtures/github_payloads/post_receive_hook_installation_repositories_added.json")
  end

  def installation_repositories_removed
    get_payload("fixtures/github_payloads/post_receive_hook_installation_repositories_deleted.json")
  end

  def github_app_push
    get_payload("fixtures/github_payloads/post_receive_hook_push_github_app.json")
  end

  def github_app_push_as_bot
    get_payload("fixtures/github_payloads/post_receive_hook_push_as_bot_github_app.json")
  end

  def get_payload(location)
    File.read(location)
  end

  def github_app_membership_organization_remove
    get_payload("fixtures/github_payloads/github_app_membership_organization_remove.json")
  end

  def github_app_team_deleted
    get_payload("fixtures/github_payloads/github_app_team_deleted.json")
  end

  def github_app_team_renamed
    get_payload("fixtures/github_payloads/github_app_team_renamed.json")
  end

  def github_app_team_changed_permissions
    get_payload("fixtures/github_payloads/github_app_team_changed_permissions.json")
  end

  def github_app_team_added_to_repo
    get_payload("fixtures/github_payloads/github_app_team_added_to_repo.json")
  end

  def github_app_team_removed_from_repo
    get_payload("fixtures/github_payloads/github_app_team_removed_from_repo.json")
  end

  def github_app_membership_user_added_to_team
    get_payload("fixtures/github_payloads/github_app_membership_user_added_to_team.json")
  end

  def github_app_membership_user_removed_from_team
    get_payload("fixtures/github_payloads/github_app_membership_user_removed_from_team.json")
  end
end
