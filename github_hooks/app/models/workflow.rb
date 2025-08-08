class Workflow < ActiveRecord::Base
  RESULT_OK = "OK"
  RESULT_BAD_REQUEST = "BAD REQUEST"

  STATE_PROCESSING = "processing"
  STATE_NO_PROJECT = "no_project"
  STATE_PR_APPROVAL = "pr_approval"
  STATE_SKIP_CI = "skip_ci"
  STATE_DELETING_BRANCH = "deleting_branch"
  STATE_SKIP_PR = "skip_pr"
  STATE_SKIP_FORKED_PR = "skip_forked_pr"
  STATE_SKIP_DRAFT_PR = "skip_draft_pr"
  STATE_SKIP_FILTERED_CONTRIBUTOR = "filtered_contributor"
  STATE_SKIP_TAG = "skip_tag"
  STATE_WHITELIST_TAG = "whitelist_tag"
  STATE_SKIP_BRANCH = "skip_branch"
  STATE_WHITELIST_BRANCH = "whitelist_branch"
  STATE_PR_NON_MERGEABLE = "pr_non_mergeable"
  STATE_PR_NOT_FOUND = "pr_not_found"
  STATE_LAUNCHING = "launching"
  STATE_LAUNCHING_FAILED = "launching_failed"
  STATE_UNAUTHORIZED_REPO = "unauthorized_repo"
  STATE_NOT_FOUND_REPO = "not_found_repo"
  STATE_MEMBER_DENIED = "member_denied"
  STATE_NON_MEMBER_DENIED = "non_member_denied"
  STATE_HOOK_VERIFICATION_FAILED = "hook_verification_failed"

  belongs_to :project
  belongs_to :branch, :optional => true

  scope :with_scheduled_pipeline, -> { where("ppl_id IS NOT NULL") }

  scope :in_organization, ->(organization_id) { joins(:project).where(:"projects.organization_id" => organization_id) }
  scope :in_project, ->(project_id) { where(:project_id => project_id) }
  scope :in_branch, ->(branch_name) { joins(:branch).where(:"branches.name" => branch_name) }
  scope :blocked_by_whitelist, -> { where(:state => [STATE_WHITELIST_TAG, STATE_WHITELIST_BRANCH]) }
  scope :blocked_by_contributor, -> { where(:state => [STATE_SKIP_FILTERED_CONTRIBUTOR]) }
  scope :recent, ->(limit) { order(:created_at => :desc).limit(limit) }
  scope :pr_number_in_git_ref, ->(number) { where(:git_ref => "refs/pull/#{number}/merge") }
  scope :initial_state, -> { where(:state => STATE_PROCESSING) }
  scope :created_before, -> (datetime) { where(Workflow.arel_table[:created_at].lt(datetime)) }
  scope :created_after, -> (datetime) { where(Workflow.arel_table[:created_at].gt(datetime)) }

  delegate :author_avatar_url, :author_email, :author_name, :pull_request_name,
    :pull_request_number, :name, :commit_message, :repo_url,
    :author_uid, :branch_name, :to => :payload

  def self.created_before_with_limit(datetime, limit)
    before_date = datetime
    after_date = datetime - limit

    created_before(before_date).created_after(after_date)
  end

  def payload
    @payload ||= build_payload
  end

  paginates_per 100

  private

  def build_payload
    case provider
    when "api"
      ::RepoHost::Api::Payload.new(request)
    when "bitbucket"
      ::RepoHost::Bitbucket::Payload.new(request)
    when "gitlab"
      ::RepoHost::Gitlab::Payload.new(request)
    when "github"
      ::RepoHost::Github::Payload.new(request["payload"])
    when "git"
      ::RepoHost::Git::Payload.new(request)
    else
      ::RepoHost::Github::Payload.new(request["payload"])
    end
  end
end
