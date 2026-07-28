# frozen_string_literal: true

require "time" # Time.parse, used to bind an approval to its comment timestamp

class Semaphore::RepoHost::Hooks::Handler # rubocop:disable Metrics/ClassLength

  # Fail-closed deadline (seconds) for the synchronous RBAC permission check in
  # can_approve_forked_pr?, so a slow/hung RBAC service can't stall the approval
  # worker; GRPC::DeadlineExceeded is caught below and treated as a denial.
  PR_APPROVAL_RBAC_DEADLINE_SECONDS = 5

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
  def self.run(workflow, logger, hook_payload = "", signature = "", retries = 0)
    # stops hooks from deleted projects from generating exceptions
    # should not be necessary when project deletion cleans up hooks
    if workflow.project.nil?
      logger.info("request-has-no-project-skipped")
      workflow.update(:state => Workflow::STATE_NO_PROJECT)

      return
    end

    verification_result = webhook_signature_valid?(logger, workflow.project.organization_id, workflow.project.repository.id, hook_payload, signature)

    if verification_result == :retry
      if retries < 10
        sidekiq_job_id = Semaphore::RepoHost::Hooks::Handler::Worker.perform_in(2.minutes, workflow.id, hook_payload, signature, retries + 1)
        logger.info("Rescheduled in Sidekiq", :sidekiq_job_id => sidekiq_job_id)
      else
        logger.info("Too many retries, skipping hook")
        workflow.update(:state => Workflow::STATE_HOOK_VERIFICATION_FAILED)
      end
      return
    end

    if verification_result == :not_verified
      logger.info("request-not-verified")
      workflow.update(:state => Workflow::STATE_HOOK_VERIFICATION_FAILED)

      return
    end

    if support_sequential_runs?(workflow) && with_predecessors?(workflow)
      Watchman.increment("hook.processing.not_in_sequence")

      sidekiq_job_id = Semaphore::RepoHost::Hooks::Handler::Worker.perform_async(workflow.id, hook_payload, signature, retries + 1)

      logger.info("Rescheduled in Sidekiq", :sidekiq_job_id => sidekiq_job_id)

      return
    end

    branch = find_branch(workflow)
    workflow.update(:branch_id => branch.id) if branch.present?

    if workflow.payload.includes_ci_skip? && (App.always_filter_skip_ci || !workflow.payload.tag?)
      logger.info("request-is-filtered")
      workflow.update(:state => Workflow::STATE_SKIP_CI)

      return
    end

    if workflow.payload.branch_deleted?
      logger.info("deleting-branch")
      workflow.update(:state => Workflow::STATE_DELETING_BRANCH)

      delete_branch(workflow, logger)
      return
    end

    organization = ::Organization.find_by_id(workflow.project.organization_id)

    # Fork head SHA the approval is bound to. Set only on the /sem-approve
    # path; used further down to fail closed if the fork pushes a new commit
    # between approval and launch (TOCTOU protection).
    approved_head_sha = nil

    if workflow.payload.pr_approval?
      # NOTE: We don't check the organization workflow restrictions here
      # because when a member uses /sem-approve, the workflow should still
      # run and be visible by the outside contributor trying to run it.
      logger.info("pr-approval")
      workflow.update(:state => Workflow::STATE_PR_APPROVAL)

      include_secrets_requested = workflow.payload.respond_to?(:pr_approval_include_secrets?) &&
                                  workflow.payload.pr_approval_include_secrets?
      enable_cache_requested = pr_approval_enable_cache_requested?(workflow.payload)

      # Capture the approver identity and comment metadata from the *comment*
      # workflow before we reassign `workflow` to the blocked forked-PR
      # workflow below (its payload is a pull_request event, not a comment).
      #
      # `requestor` (the login) is display/audit only; authorization keys off
      # the immutable `requestor_uid` because GitHub logins are renameable and
      # reusable, so a stale/renamed account could otherwise map a commenter to
      # a different Semaphore user who happens to hold that login.
      requestor = workflow.payload.comment_author
      requestor_uid = workflow.payload.respond_to?(:comment_author_uid) ? workflow.payload.comment_author_uid : nil
      comment_id = workflow.payload.respond_to?(:comment_id) ? workflow.payload.comment_id : nil
      approved_at = workflow.payload.respond_to?(:comment_created_at) ? workflow.payload.comment_created_at : nil
      issue_number = workflow.payload.issue_number

      # Approving a forked PR triggers a privileged workflow run (optionally
      # with secrets/cache), so it requires the permission to start/rerun a
      # pipeline (project.job.rerun) — not mere read access. Fails closed.
      unless can_approve_forked_pr?(workflow.project, requestor_uid, logger)
        logger.info("pr-approval-denied", :requestor => requestor)
        Watchman.increment("hooks.pr_approval.denied")
        return
      end

      # Bind the approval to the fork state that existed when the comment was
      # written. Picking the newest blocked workflow unconditionally lets a
      # contributor who pushes a new commit *after* the maintainer approves get
      # that newer, unreviewed workflow selected and granted secrets/cache
      # (the async worker can lag the comment by up to ~20 min of signature
      # retries, widening the window). We therefore reject any blocked workflow
      # created after the approval comment, and fail closed if we cannot
      # establish when the comment was written.
      approval_comment_time = parse_approval_comment_time(approved_at)
      if approval_comment_time.nil?
        logger.info("pr-approval-missing-comment-timestamp", :requestor => requestor)
        Watchman.increment("hooks.pr_approval.missing_comment_time")
        return
      end

      workflow = Workflow
        .in_project(workflow.project_id)
        .blocked_by_contributor
        .pr_number_in_git_ref(issue_number)
        .created_before(approval_comment_time)
        .recent(1).first

      return unless workflow

      # SHA binding (TOCTOU): pin the approval to the fork head that was
      # present when /sem-approve was processed. `commit_sha` on a blocked
      # forked-PR workflow is the fork head SHA recorded when that PR event
      # arrived. Before launching, we re-check the live PR head against this
      # value and fail closed if the fork pushed a new commit in the meantime
      # (see the STATE_PR_APPROVAL_STALE guard in the pull_request? block).
      #
      # A blank recorded head means we cannot bind the grant to a reviewed
      # commit, so fail closed here rather than let the downstream guard be
      # skipped (it is guarded on `approved_head_sha.present?`).
      approved_head_sha = workflow.commit_sha
      if approved_head_sha.blank?
        logger.info("pr-approval-missing-head-sha", :workflow_id => workflow.id)
        Watchman.increment("hooks.pr_approval.missing_head_sha")
        workflow.update(:state => Workflow::STATE_PR_APPROVAL_STALE)
        return
      end

      include_secrets_enabled = approval_option_enabled?(workflow.project, :allow_sem_approve_include_secrets)
      enable_cache_enabled = approval_enable_cache_option_enabled?(workflow.project)

      # Authorization is already established by can_approve_forked_pr? above;
      # each option additionally requires its per-project setting to be on.
      include_secrets = approved_sem_approve_option(
        :requested => include_secrets_requested,
        :enabled => include_secrets_enabled,
        :option => "--include-secrets",
        :logger => logger
      )
      enable_cache = approved_sem_approve_option(
        :requested => enable_cache_requested,
        :enabled => enable_cache_enabled,
        :option => "--enable-cache",
        :logger => logger
      )

      # Fail closed if the approver explicitly requested an option the project
      # has not enabled, rather than silently downgrading to a bare approval —
      # that would consume the one-shot approval on a run without the requested
      # secrets/cache. Leave the workflow blocked so the option can be enabled
      # (or the command re-issued without it). Consistent with how a misspelled
      # option is rejected by the parser.
      if (include_secrets_requested && !include_secrets) || (enable_cache_requested && !enable_cache)
        logger.info("pr-approval-option-not-enabled",
                    :include_secrets_requested => include_secrets_requested,
                    :enable_cache_requested => enable_cache_requested)
        Watchman.increment("hooks.pr_approval.option_not_enabled")
        return
      end

      options_persisted = mark_workflow_with_pr_approval_options(
        workflow,
        :include_secrets => include_secrets,
        :enable_cache => enable_cache,
        :approver => requestor,
        :approver_uid => requestor_uid,
        :approved_head_sha => approved_head_sha,
        :approved_at => approved_at,
        :comment_id => comment_id,
        :logger => logger
      )
      return unless options_persisted

    elsif workflow.payload.pull_request_within_repo?
      # Check if project members can run pull-request workflows for this organization.
      # Note that we do not need to check if non-members can run pull-request workflows,
      # because in order to create a pull-request in the repository, the user must be a member.
      if organization.deny_member_workflows
        logger.info("member-workflow-denied")
        workflow.update(:state => Workflow::STATE_MEMBER_DENIED)
        return
      end

      unless workflow.project.build_pr
        logger.info("skip-prs")
        workflow.update(:state => Workflow::STATE_SKIP_PR)

        return
      end
    elsif workflow.payload.pull_request_forked_repo?
      unless workflow.project.build_forked_pr
        logger.info("skip-forked-prs")
        workflow.update(:state => Workflow::STATE_SKIP_FORKED_PR)

        return
      end

      if workflow.payload.draft_pull_request? && !draft_pr_allowed?(workflow.project)
        logger.info("skip-draft-prs")
        workflow.update(:state => Workflow::STATE_SKIP_DRAFT_PR)

        return
      end

      requestor = workflow.payload.pr_head_repo_owner

      # Check if this a member, and if the organization allows member workflows.
      is_project_member = project_member?(workflow.project, requestor)
      if organization.deny_member_workflows && is_project_member
        logger.info("member-workflow-denied")
        workflow.update(:state => Workflow::STATE_MEMBER_DENIED)
        return
      end

      # Check if this not a member, and if the organization allows non-member workflows.
      if organization.deny_non_member_workflows && !is_project_member
        logger.info("non-member-workflow-denied")
        workflow.update(:state => Workflow::STATE_NON_MEMBER_DENIED)
        return
      end

      # Lastly, check project settings restrictions on forked pull request
      unless forked_pr_allowed?(requestor, workflow.project)
        logger.info("skip-filtered-contributor")
        workflow.update(:state => Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR)

        return
      end
    elsif workflow.payload.tag?

      # Check if project members can run tag workflows for this organization.
      # Note that we do not need to check if non-members can run tag workflows,
      # because in order to create a tag in the repository, the user must be a member.
      if organization.deny_member_workflows
        logger.info("member-workflow-denied")
        workflow.update(:state => Workflow::STATE_MEMBER_DENIED)
        return
      end

      unless workflow.project.build_tag
        logger.info("skip-tags")
        workflow.update(:state => Workflow::STATE_SKIP_TAG)

        return
      end

      unless whitelisted?(workflow.payload.tag_name, workflow.project.whitelist_tags, logger)
        logger.info("tag-not-whitelisted")
        workflow.update(:state => Workflow::STATE_WHITELIST_TAG)

        return
      end
    else
      # Check if project members can run branch workflows for this organization.
      # Note that we do not need to check if non-members can run branch workflows,
      # because in order to create a branch in the repository, the user must be a member.
      if organization.deny_member_workflows
        logger.info("member-workflow-denied")
        workflow.update(:state => Workflow::STATE_MEMBER_DENIED)
        return
      end

      unless workflow.project.build_branch
        logger.info("skip-branches")
        workflow.update(:state => Workflow::STATE_SKIP_BRANCH)

        return
      end

      unless whitelisted?(workflow.branch_name, workflow.project.whitelist_branches, logger) || branch&.run_regardless_of_whitelist?
        logger.info("branch-not-whitelisted")
        workflow.update(:state => Workflow::STATE_WHITELIST_BRANCH)

        return
      end
    end

    if workflow.payload.pull_request?
      begin
        if workflow.payload.draft_pull_request? && !draft_pr_allowed?(workflow.project)
          logger.info("skip-draft-prs")
          workflow.update(:state => Workflow::STATE_SKIP_DRAFT_PR)

          return
        end

        # Skip ready_for_review events when build_draft_pr is enabled
        # (the PR was already building as a draft)
        if draft_pr_allowed?(workflow.project) && workflow.payload.pull_request_ready_for_review?
          logger.info("skip-ready-for-review-when-building-drafts")
          workflow.update(:state => Workflow::STATE_SKIP_DRAFT_PR)
          return
        end

        state, meta, msg = update_pr_data(workflow.project, workflow.pull_request_number, workflow.commit_sha)
        case state
        when :not_found
          logger.info("pr-not-found #{msg}")
          workflow.update(:state => Workflow::STATE_PR_NOT_FOUND)

          return
        when :non_mergeable
          update_pull_request_mergeable(workflow, meta[:mergeable])

          logger.info("pr-non-mergeable")
          workflow.update(:state => Workflow::STATE_PR_NON_MERGEABLE)

          return
        when :skip_ci
          logger.info("request-is-filtered")
          workflow.update(:state => Workflow::STATE_SKIP_CI)

          return
        when :without_reference
          # No semaphoreci ref was created, so the launch runs the recorded
          # fork head (approved_head_sha) directly rather than a freshly
          # resolved merge commit — no TOCTOU window to guard here.
          logger.info("without-reference")
          workflow.update(:commit_author => meta[:commit_author])
        else
          # For /sem-approve launches, the merge commit is derived from the
          # *live* PR head. Refuse to run (and to hand over any granted
          # secrets/cache) if the fork pushed a new commit since approval.
          if approved_head_sha.present? && !approved_pr_head_unchanged?(meta, approved_head_sha)
            logger.info("pr-approval-stale-head",
                        :approved_head_sha => approved_head_sha,
                        :live_head_sha => meta[:head_sha])
            Watchman.increment("hooks.pr_approval.stale_head")
            workflow.update(:state => Workflow::STATE_PR_APPROVAL_STALE)

            return
          end

          workflow.update(:commit_author => meta[:commit_author], :commit_sha => meta[:merge_commit_sha], :git_ref => meta[:ref])
        end
      rescue RepoHost::RemoteException::Unknown => e
        logger.error("Unknown error", error: e.message)
        raise e.class, e.message
      end
    end

    branch = find_or_create_branch(workflow, logger)
    if workflow.payload.pull_request?
      update_pull_request_mergeable(workflow, meta[:mergeable])
    end

    launch_pipeline(branch, workflow, logger)
  rescue RepoHost::RemoteException::Unauthorized => e
    logger.info("unauthorized-repository: #{e.message}")
    workflow.update(:state => Workflow::STATE_UNAUTHORIZED_REPO)
  rescue RepoHost::RemoteException::NotFound => e
    logger.info("not-found-repository: #{e.message}")
    workflow.update(:state => Workflow::STATE_NOT_FOUND_REPO)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength

  def self.get_pr_data(repo_host, project, number, counter)
    pr = repo_host.pull_request(project.repo_owner_and_name, number)

    if !pr[:mergeable].nil? || counter > 7
      return [pr, pr[:merge_commit_sha], pr[:mergeable], ""]
    end

    sleep(1.1**counter)
    get_pr_data(repo_host, project, number, counter + 1)
  rescue RepoHost::RemoteException::NotFound => e
    if counter > 7
      return [nil, "", false, e]
    end

    sleep(1.1**counter)
    get_pr_data(repo_host, project, number, counter + 1)
  end

  #
  # Used also at InternalApi::RepoProxy::PrPayload
  #
  def self.update_pr_data(project, number, commit_sha = nil, allow_skip = true)
    repo_host = ::RepoHost::Factory.create_from_project(project)
    repo_host.validate_token_presence!

    pr, merge_commit_sha, mergeable, msg = get_pr_data(repo_host, project, number, 0)

    if pr == nil
      return [:not_found, {}, msg]
    end

    unless mergeable
      return [:non_mergeable, { :pr => pr, :mergeable => mergeable }, msg]
    end

    commit_sha ||= pr[:head][:sha]
    # Live fork head SHA of the PR, used by the /sem-approve path to detect a
    # commit injected between approval and launch. Read defensively so that
    # payloads without a :head entry (e.g. in tests) simply yield nil.
    head_sha = pr[:head] && pr[:head][:sha]
    commit = repo_host.commit(project.repo_owner_and_name, commit_sha)
    commit_author = commit.try(:author).try(:login)
    commit_message = commit.try(:commit).try(:message).to_s

    if allow_skip && ::Semaphore::SkipCi.new.call(commit_message)
      return [:skip_ci, { :pr => pr, :mergeable => mergeable }, msg]
    end

    begin
      ref = "refs/semaphoreci/#{merge_commit_sha}"
      ensure_ref(repo_host, project.repo_owner_and_name, ref, merge_commit_sha)

      [:ok, { :pr => pr, :ref => ref, :merge_commit_sha => merge_commit_sha, :mergeable => mergeable, :commit_author => commit_author, :head_sha => head_sha }, msg]
    rescue RepoHost::RemoteException::Unauthorized, RepoHost::RemoteException::NotFound
      [:without_reference, { :mergeable => mergeable, :commit_author => commit_author }, ""]
    end
  end

  def self.ensure_ref(repo_host, repo_slug, ref, sha)
    # Try to create the ref directly. If GitHub reports the ref already
    # exists (422 "Reference already exists" → ReferenceAlreadyExists),
    # treat that as success — the post-condition (the ref is present
    # for this SHA) is satisfied either way.
    #
    # Skipping the probe `repo_host.reference(...)` saves one GitHub API
    # request per PR processed. Do not re-introduce a pre-check GET here.
    repo_host.create_ref(repo_slug, ref, sha)
  rescue ::RepoHost::RemoteException::ReferenceAlreadyExists
    Watchman.increment("github_hooks.ensure_ref.ref_already_exists")
    Logman.info("github_hooks.ensure_ref ref_already_exists repo=#{repo_slug} ref=#{ref} sha=#{sha}")
    nil
  end

  def self.mark_workflow_with_pr_approval_options(workflow, include_secrets: false, enable_cache: false, approver: nil, approver_uid: nil, approved_head_sha: nil, approved_at: nil, comment_id: nil, logger: nil) # rubocop:disable Metrics/ParameterLists
    return true unless include_secrets || enable_cache

    payload = JSON.parse(workflow.request["payload"])

    # Back-compat boolean markers, still consumed by RepoHost::Github::Payload,
    # the repo_proxy Describe response, and zebra's secret/cache gating.
    payload["semaphore_approval_include_secrets"] = true if include_secrets
    payload["semaphore_approval_enable_cache"] = true if enable_cache

    # Typed, auditable approval record: who approved (login + immutable uid),
    # the reviewed fork head the grant is bound to, when, and the source
    # comment id.
    payload["semaphore_approval"] = {
      "include_secrets" => include_secrets,
      "enable_cache" => enable_cache,
      "approver" => approver,
      "approver_uid" => approver_uid,
      "approved_head_sha" => approved_head_sha,
      "approved_at" => approved_at,
      "comment_id" => comment_id
    }

    request = workflow.request.merge("payload" => payload.to_json)
    if workflow.update(:request => request)
      logger&.info("pr-approval-options-persisted",
                   :include_secrets => include_secrets,
                   :enable_cache => enable_cache,
                   :approver => approver,
                   :approved_head_sha => approved_head_sha,
                   :comment_id => comment_id)
      return true
    end

    report_pr_approval_option_persist_failure(workflow, logger, "workflow_update_failed")
    false
  rescue StandardError => e
    report_pr_approval_option_persist_failure(workflow, logger, e.message)
    false
  end

  def self.approved_sem_approve_option(requested:, enabled:, option:, logger:)
    return false unless requested

    unless enabled
      logger&.info("pr-approval-option-dropped", :option => option, :reason => "project_option_disabled")
      Watchman.increment("hooks.pr_approval.option_dropped", tags: [option.delete_prefix("--"), "project_option_disabled"])
      return false
    end

    true
  end

  # True when the live PR head (as returned by update_pr_data) is present and
  # still equals the SHA the approval was bound to. A blank/missing live head
  # is treated as "changed" so the caller fails closed.
  def self.approved_pr_head_unchanged?(meta, approved_head_sha)
    live_head_sha = meta[:head_sha]

    live_head_sha.present? && live_head_sha == approved_head_sha
  end

  def self.report_pr_approval_option_persist_failure(workflow, logger, reason)
    workflow_id = workflow.respond_to?(:id) ? workflow.id : nil

    logger&.error("pr-approval-option-persist-failed", :reason => reason, :workflow_id => workflow_id)
    Watchman.increment("hooks.pr_approval.option_persist_failed")
  end

  def self.approval_option_enabled?(project, option)
    project.respond_to?(option) && project.public_send(option) == true
  end

  def self.approval_enable_cache_option_enabled?(project)
    approval_option_enabled?(project, :allow_sem_approve_enable_cache)
  end

  def self.pr_approval_enable_cache_requested?(payload)
    payload.respond_to?(:pr_approval_enable_cache?) && payload.pr_approval_enable_cache?
  end

  # Authorization gate for /sem-approve. Approving a forked PR starts a
  # privileged pipeline run, so it requires the same permission as
  # starting/rerunning a pipeline (project.job.rerun) rather than plain
  # read access (project.view). Any failure (unknown user, RBAC error)
  # fails closed.
  #
  # The commenter is resolved by immutable GitHub UID, not by login: logins
  # are renameable and reusable, so keying off the login could authorize a
  # different Semaphore account than the one that actually commented.
  def self.can_approve_forked_pr?(project, github_uid, logger = nil)
    return false if github_uid.blank?

    repo = RepoHostAccount.github.find_by(:github_uid => github_uid)
    return false if repo.nil?

    client = InternalApi::RBAC::RBAC::Stub.new(App.rbac_internal_url, :this_channel_is_insecure)
    req = ::InternalApi::RBAC::ListUserPermissionsRequest.new(
      :user_id => repo.user_id,
      :org_id => project.organization_id,
      :project_id => project.id
    )

    client.list_user_permissions(req, :deadline => Time.now + PR_APPROVAL_RBAC_DEADLINE_SECONDS)
          .permissions.include?("project.job.rerun")
  rescue StandardError => e
    logger&.error(
      "pr-approval-permission-check-failed",
      :error => e.message,
      :requestor_uid => github_uid,
      :project_id => project.id
    )
    Watchman.increment("hooks.pr_approval.permission_check_failed")
    false
  end

  # Parse the approval comment's created_at (an ISO8601 string from the GitHub
  # issue_comment payload) into a Time. Returns nil for a missing/unparseable
  # value so the caller can fail closed — we must know when the comment was
  # written to bind the approval to the fork state at that moment.
  def self.parse_approval_comment_time(value)
    return nil if value.blank?

    Time.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def self.forked_pr_allowed?(requestor, project)
    project.allowed_contributors.blank? ||
      project.allowed_contributors.split(",").include?(requestor) ||
      project_member?(project, requestor)
  end

  def self.draft_pr_allowed?(project)
    if project.build_draft_pr
      return true
    end

    false
  end

  def self.project_member?(project, github_username)
    repo = RepoHostAccount.github.find_by(:login => github_username)

    return false if repo.nil?

    client = InternalApi::RBAC::RBAC::Stub.new(App.rbac_internal_url, :this_channel_is_insecure)
    req = ::InternalApi::RBAC::ListUserPermissionsRequest.new(
      :user_id => repo.user_id,
      :org_id => project.organization_id,
      :project_id => project.id
    )

    client.list_user_permissions(req).permissions.include?("project.view")
  end

  def self.update_pull_request_mergeable(workflow, mergeable)
    if (branch = find_branch(workflow))
      mergeable_before = branch.pull_request_mergeable
      branch.update(:pull_request_mergeable => mergeable)
      if !mergeable && mergeable_before
        Semaphore::Events::PullRequestUnmergeable.emit(workflow.project_id, branch.name)
      end
    end
  end

  def self.delete_branch(workflow, logger)
    project = workflow.project
    branch  = find_branch(workflow)

    if branch.blank?
      logger.info("skipping-branch-delete", :reason => "Branch does not exists")

      return
    end

    logger.add(:branch_id => branch.id)
    logger.info("deleting-branch")

    terminate_pipelines(branch, logger)

    branch.archive

    project.touch
  end

  def self.find_branch(workflow)
    workflow.project.find_branch(workflow.payload.branch)
  end

  def self.find_or_create_branch(workflow, logger)
    logger.info("finding-or-creating-branch")

    branch = ::Branch.find_or_create_for_workflow(workflow)
    branch.unarchive
    workflow.update(:branch_id => branch.id)
    logger.add(:branch_id => branch.id)

    branch
  end

  def self.terminate_pipelines(branch, logger)
    client = InternalApi::Plumber::Admin::Stub.new(App.plumber_internal_url, :this_channel_is_insecure)
    request = InternalApi::Plumber::TerminateAllRequest.new(
      :project_id => branch.project_id,
      :branch_name => branch.name,
      :reason => InternalApi::Plumber::TerminateAllRequest::Reason::BRANCH_DELETION
    )

    logger.info("Sending TerminateAllRequest to Plumber")

    response = client.terminate_all(request)

    if response.response_status.code == :OK
      logger.info("terminating-pipelines-success")
    else
      logger.info("terminating-pipelines-failed")
    end
  end

  def self.launch_pipeline(branch, workflow, logger)
    client  = InternalApi::PlumberWF::WorkflowService::Stub.new(App.plumber_internal_url, :this_channel_is_insecure)
    request = InternalApi::PlumberWF::ScheduleRequest.new(
      :service => InternalApi::PlumberWF::ScheduleRequest::ServiceType::GIT_HUB,
      :repo => InternalApi::PlumberWF::ScheduleRequest::Repo.new(
        :owner => branch.project.repository.owner,
        :repo_name => branch.project.repository.name,
        :branch_name => branch.name,
        :commit_sha => workflow.commit_sha,
        :repository_id => branch.project.repository.id
      ),
      :project_id => branch.project_id,
      :branch_id => branch.id,
      :hook_id => workflow.id,
      :request_token => workflow.id,
      :snapshot_id => "",
      :definition_file => branch.project.repository.pipeline_file,
      :requester_id => requester_id(workflow),
      :organization_id => branch.project.organization_id,
      :label => label(workflow)
    )

    logger.info("Sending ScheduleRequest to Plumber")

    response = client.schedule(request)

    if response.status.code == :OK
      logger.info("Processing Hook #{workflow.id} => Plumber responded with #{response.status.code} code")

      submit_metrics(workflow)
      workflow.update(:ppl_id => response.ppl_id)

      logger.info("launching-build")
      workflow.update(:state => Workflow::STATE_LAUNCHING)

      {
        :code => response.status.code,
        :ppl_id => response.ppl_id,
        :wf_id => response.wf_id
      }
    else
      logger.info("launching-build-failed")
      workflow.update(:state => Workflow::STATE_LAUNCHING_FAILED)

      raise "The Plumber returned #{response.status.inspect}"
    end
  end

  def self.submit_metrics(workflow)
    duration = Time.now.to_ms - workflow.created_at.to_ms

    Watchman.submit("hook.processing.duration", duration, :timing)
  end

  def self.requester_id(workflow)
    if workflow.payload.sent_by_bot_account?
      repo_host = RepoHostAccount.github.find_by(:login => workflow.payload.author_name)
    else
      repo_host = RepoHostAccount.github.find_by(:github_uid => workflow.author_uid)
    end

    if(repo_host)
      repo_host.user_id
    else
      ""
    end
  end

  def self.label(workflow)
    if workflow.payload.pull_request?
      workflow.pull_request_number.to_s
    elsif workflow.payload.tag?
      workflow.payload.tag_name
    else
      workflow.branch_name
    end
  end

  def self.whitelisted?(ref, whitelist, logger)
    Timeout.timeout(2) {
      return true if whitelist.empty?

      whitelist.any? do |pattern|
        if pattern.starts_with?("/") && pattern.ends_with?("/")
          ref.match?(pattern.slice(1..-2))
        else
          ref == pattern
        end
      end.tap do |whitelisted|
        unless whitelisted
          Watchman.increment("IncommingHooks.whitelist_block", { external: true })
        end
      end
    }
  rescue Timeout::Error
    logger.info("whitelist timeout error")
    Watchman.increment("hook.processing.whitelist_timeout")
    true
  rescue RegexpError
    logger.info("whitelist regexp error")
    false
  end

  def self.with_predecessors?(workflow)
    Workflow.in_project(workflow.project_id).where(provider: "github").initial_state.created_before_with_limit(workflow.created_at, 10.minutes).exists?
  end

  def self.support_sequential_runs?(_workflow)
    # This feature is currently disabled for everyone
    false
  end

  def self.webhook_signature_valid?(logger, organization_id, repository_id, payload, signature)
    client = InternalApi::Repository::RepositoryService::Stub.new(App.repository_hub_url, :this_channel_is_insecure)
    request = InternalApi::Repository::VerifyWebhookSignatureRequest.new(
      :organization_id => organization_id,
      :repository_id => repository_id,
      :payload => payload,
      :signature => signature
    )

    response = client.verify_webhook_signature(request)
    if response.valid
      logger.info("Webhook signature verification passed", repository_id: repository_id)
      Watchman.increment("hooks.processing.verify_signature.success", tags: ["github"])
      :ok
    else
      Watchman.increment("hooks.processing.verify_signature.fail", tags: ["github"])
      logger.info("Webhook signature verification failed for repository", repository_id: repository_id)
      # Hook signature verification failed, ignore
      :not_verified
    end
  rescue StandardError => e
    Watchman.increment("hooks.processing.verify_signature.error", tags: ["github"])
    logger.info("Webhook signature verification errored", error: e)
    # RepositoryHub request failed, retry
    :retry
  end
end
