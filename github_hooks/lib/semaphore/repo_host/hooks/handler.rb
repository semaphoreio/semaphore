# frozen_string_literal: true

class Semaphore::RepoHost::Hooks::Handler # rubocop:disable Metrics/ClassLength

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

    if workflow.payload.pr_approval?
      # NOTE: We don't check the organization workflow restrictions here
      # because when a member uses /sem-approve, the workflow should still
      # run and be visible by the outside contributor trying to run it.
      logger.info("pr-approval")
      workflow.update(:state => Workflow::STATE_PR_APPROVAL)

      requestor = workflow.payload.comment_author

      return unless forked_pr_allowed?(requestor, workflow.project)

      workflow = Workflow
        .in_project(workflow.project_id)
        .blocked_by_contributor
        .pr_number_in_git_ref(workflow.payload.issue_number)
        .recent(1).first

      return unless workflow
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
          logger.info("without-reference")
          workflow.update(:commit_author => meta[:commit_author])
        else
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
    commit = repo_host.commit(project.repo_owner_and_name, commit_sha)
    commit_author = commit.try(:author).try(:login)
    commit_message = commit.try(:commit).try(:message).to_s

    if allow_skip && ::Semaphore::SkipCi.new.call(commit_message)
      return [:skip_ci, { :pr => pr, :mergeable => mergeable }, msg]
    end

    begin
      ref = "refs/semaphoreci/#{merge_commit_sha}"
      ensure_ref(repo_host, project.repo_owner_and_name, ref, merge_commit_sha)

      [:ok, { :pr => pr, :ref => ref, :merge_commit_sha => merge_commit_sha, :mergeable => mergeable, :commit_author => commit_author }, msg]
    rescue RepoHost::RemoteException::Unauthorized, RepoHost::RemoteException::NotFound
      [:without_reference, { :mergeable => mergeable, :commit_author => commit_author }, ""]
    end
  end

  def self.ensure_ref(repo_host, repo_slug, ref, sha)
    repo_host.reference(repo_slug, ref.delete_prefix("refs/"))
  rescue ::RepoHost::RemoteException::NotFound
    repo_host.create_ref(repo_slug, ref, sha)
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
    repo = RepoHostAccount.find_by(:login => github_username)

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
        Semaphore::Events::PullRequestUnmergeable.emit(workflow, branch)
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
