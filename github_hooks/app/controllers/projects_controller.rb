class ProjectsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def repo_host_post_commit_hook
    return head :forbidden if App.ee? && !LicenseVerifier.verify

    Watchman.benchmark("repo_host_post_commit_hooks.controller.duration") do
      new_request = Semaphore::RepoHost::Hooks::Request.new(repo_host_request)

      logger = Logman.new
      logger.add(:delivery_id => new_request.delivery_id)
      logger.info("Request Started")

      Watchman.increment("IncommingHooks.received", { external: true })

      hook_params = Semaphore::RepoHost::Hooks::Request.normalize_params(repo_host_request_params)
      webhook_filter = Semaphore::RepoHost::WebhookFilter.create_webhook_filter(new_request, hook_params[:payload])

      if webhook_filter.unsupported_webhook?
        Watchman.increment("repo_host_post_commit_hooks.controller.unsupported_webhook")
        logger.info("Unsupported Webhook")
        head :ok and return
      end

      if webhook_filter.github_app_webhook? || webhook_filter.github_app_installation_webhook?
        signature = repo_host_request.headers["X-Hub-Signature-256"] || ""
        secret = Semaphore::GithubApp::Credentials.github_app_webhook_secret

        if Semaphore::GithubApp::Hook.webhook_signature_valid?(secret, signature, repo_host_request.body.string) != :ok
          logger.error("Webhook validation failed")
          head :not_found and return
        end
      end

      if webhook_filter.github_app_installation_webhook?
        Watchman.increment("repo_host_post_commit_hooks.controller.github_app_webhook")
        logger.info("Github App Webhook")

        payload = JSON.parse(hook_params[:payload])
        payload["action"] = JSON.parse(repo_host_request.body.string)["action"]

        Semaphore::GithubApp::Hook.process(new_request.event, payload)

        head :ok and return
      end

      if webhook_filter.github_app_webhook?
        Watchman.increment("repo_host_post_commit_hooks.controller.github_app_webhook")

        if webhook_filter.repository_webhook?
          logger.info("GitHub APP Repository Webhook")

          Watchman.increment("repo_host_post_commit_hooks.controller.repository_webhook")

          Semaphore::GithubApp::Repositories::Worker.perform_async(webhook_filter.installation_id)

          head :ok and return
        end

        projects = find_github_app_projects(webhook_filter.repository, webhook_filter.installation_id)
      else
        projects = [Project.find_by(:id => repo_host_request_params["hash_id"])].compact
      end

      if projects.empty?
        logger.info("Project Not Found")
        head :not_found and return
      end

      projects.each do |project|
        organization = project.organization

        logger.add(:project_id => project.id, :organization_id => organization.id)

        if organization.suspended
          logger.info("Organization Suspended")

          next
        end

        signature = repo_host_request.headers["X-Hub-Signature-256"]

        # Rubocop insisted on making this a one big if, istead of 2 nested if statements
        # We are validating a signature from each webhook coming from github app above
        # in this function, (currently line 29), and we are validating signatures for every webhook
        # coming from a repository within the hook handler.

        # Only exception to the signature verification checks are repository level webhooks that do not generate
        # a workflow (for example new member added to repo, or repository metadata changed). That will be covered
        # in the following if block.
        if (webhook_filter.repository_webhook? || (webhook_filter.member_webhook? && !webhook_filter.github_app_webhook?)) && !Semaphore::RepoHost::Hooks::Handler.webhook_signature_valid?(logger, project.organization.id, project.repository.id, repo_host_request.raw_post, signature)
          logger.error("Webhook validation for repository changed and repository member events failed")
          next
        end

        if webhook_filter.member_webhook?
          Watchman.increment("repo_host_post_commit_hooks.controller.member_webhook")
          logger.info("Member Webhook")

          Semaphore::Events::ProjectCollaboratorsChanged.emit(project)
          Semaphore::GithubApp::Collaborators::Worker.perform_async(project.repo_owner_and_name)

          next
        end

        if webhook_filter.repository_webhook?
          logger.info("Repository Webhook")

          if webhook_filter.github_app_webhook?
            logger.info("Skip for GitHub App")
          else
            Watchman.increment("repo_host_post_commit_hooks.controller.repository_webhook")

            Semaphore::Events::RemoteRepositoryChanged.emit(webhook_filter.repository)
          end

          next
        end

        workflow = Semaphore::RepoHost::Hooks::Recorder.record_hook(hook_params, project)
        logger.add(:post_commit_request_id => workflow.id)
        logger.info("Saved Request")

        if webhook_filter.unavailable_payload?
          Watchman.increment("repo_host_post_commit_hooks.controller.no_payload")

          logger.error("No Payload")

          workflow.update_attribute(:result, Workflow::RESULT_BAD_REQUEST)

          next
        end

        workflow.update_attribute(:result, Workflow::RESULT_OK)

        Watchman.increment("IncommingHooks.processed", { external: true })

        sidekiq_job_id = Semaphore::RepoHost::Hooks::Handler::Worker.perform_async(workflow.id, repo_host_request.raw_post, signature, 0)

        logger.info("Enqueud in Sidekiq", :sidekiq_job_id => sidekiq_job_id)
      end

      head :ok
    end
  end

  private

  def find_github_app_projects(repository, installation_id)
    if repository
      owner = repository["owner"]["login"]
      names = repository["name"]
    else
      installation = GithubAppInstallation.find_by(:installation_id => installation_id)
      return [] if installation.nil? || installation.repositories.empty?

      owner = installation.repositories.first.split("/").first
      names = installation.repositories.map { |repo| repo.split("/").last }
    end

    Repository.includes(:project).where(
      :integration_type => "github_app", :name => names, :owner => owner
    ).map(&:project)
  end

  def repo_host_request
    request
  end

  def repo_host_request_params
    params
  end
end
