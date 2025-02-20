# encoding: UTF-8

module RepoHost::Bitbucket::Responses::Payload
  module_function

  def branch_deletion
    get_payload("fixtures/bitbucket_payloads/branch_deletion.json")
  end

  def new_branch_with_new_commits
    get_payload("fixtures/bitbucket_payloads/new_branch_with_new_commits.json")
  end

  def new_branch_without_new_commits
    get_payload("fixtures/bitbucket_payloads/new_branch_without_new_commits.json")
  end

  def pull_request_create_commend_on_opened_pr
    get_payload("fixtures/bitbucket_payloads/pull_request_create_commend_on_opened_pr.json")
  end

  def pull_request_declined
    get_payload("fixtures/bitbucket_payloads/pull_request_declined.json")
  end

  def pull_request_open_from_fork
    get_payload("fixtures/bitbucket_payloads/pull_request_open_from_fork.json")
  end

  def pull_request_open
    get_payload("fixtures/bitbucket_payloads/pull_request_open.json")
  end

  def pull_request_push_on_branch_with_opened_pr
    get_payload("fixtures/bitbucket_payloads/pull_request_push_on_branch_with_opened_pr.json")
  end

  def pull_request_update
    get_payload("fixtures/bitbucket_payloads/pull_request_update.json")
  end

  def push_annotated_tags
    get_payload("fixtures/bitbucket_payloads/push_annotated_tags.json")
  end

  def push_commit_force_push
    get_payload("fixtures/bitbucket_payloads/push_commit_force_push.json")
  end

  def push_multiple_commits
    get_payload("fixtures/bitbucket_payloads/push_multiple_commits.json")
  end

  def push_commit
    get_payload("fixtures/bitbucket_payloads/push_commit.json")
  end

  def push_lightweight_tag
    get_payload("fixtures/bitbucket_payloads/push_lightweight_tag.json")
  end

  def push_commit_empty_payload
    get_payload("fixtures/bitbucket_payloads/push_commit_empty_payload.json")
  end

  def get_payload(location)
    File.read(location)
  end
end
