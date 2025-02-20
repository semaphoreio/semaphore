module RepoHost::Github

  # This class repsresents every call that system is making
  # towards Github API. It is a sort of interface that every
  # repo host client should follow
  class Client
    GITHUB_EXCEPTION = [
      Octokit::Unauthorized,
      Octokit::NotFound,
      Octokit::UnprocessableEntity,
      Octokit::TooManyRequests,
      Octokit::ServiceUnavailable,
      Octokit::InternalServerError,
      Octokit::Forbidden,
      Octokit::AccountSuspended,
      Octokit::RepositoryUnavailable
    ]

    AUTO_PAGINATE = true
    OWNER_TYPE_USER = "User"
    OWNER_TYPE_ORGANIZATION = "Organization"
    WEBHOOK_OPTIONS = { :events => ["push", "pull_request", "member"] }

    Octokit.default_media_type = "application/vnd.github.moondragon+json"

    def initialize(token = nil)
      @token = token
    end

    def rate_limit_remaining
      user_client.rate_limit.remaining()
    end

    def token_valid?
      validate_token_presence!

      app_client.check_application_authorization(@token).present?
    rescue Octokit::ServiceUnavailable, Octokit::InternalServerError => exception
      handle_octokit_exceptions(exception)
    rescue ::RepoHost::RemoteException::Unauthorized
      false
    rescue *GITHUB_EXCEPTION
      false
    end

    def validate_token_presence!
      raise ::RepoHost::RemoteException::Unauthorized, "Empty token" if @token.to_s.empty?
    end

    def revoke_connection
      app_client.revoke_application_authorization(@token)
    end

    def repositories
      user_repositories
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def group_repositories
      organizations_and_repositories
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def repository(repo)
      user_client.repository(repo)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def organizations
      user_client.organizations
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def user(login)
      user_client.user(login)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def create_hook(repo, hook_name, config)
      user_client.create_hook(repo, hook_name, config, WEBHOOK_OPTIONS)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def hook(repo, id)
      user_client.hook(repo, id)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def deploy_key(repo, id)
      user_client.deploy_key(repo, id)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def remove_hook(repo, id)
      user_client.remove_hook(repo, id)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def branches(repo)
      user_client.branches(repo)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def branch(repo, branch_name)
      user_client.branch(repo, branch_name)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def tag(repo, tag_sha)
      user_client.tag(repo, tag_sha)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def reference(repo, reference)
      user_client.ref(repo, reference)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def commit(repo, sha)
      user_client.commit(repo, sha)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def collaborators(repo)
      user_client.collaborators(repo)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def user_teams
      user_client.user_teams
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def team_repositories(team_id)
      user_client.team_repositories(team_id)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def add_deploy_key(repo, title, key)
      user_client.add_deploy_key(repo, title, key, :read_only => true)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def remove_deploy_key(repo, deploy_key_remote_id)
      user_client.remove_deploy_key(repo, deploy_key_remote_id)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def create_status(repo, sha, state, options)
      user_client.create_status(repo, sha, state, options)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def pull_request(repo, number)
      user_client.pull_request(repo, number)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def pull_request_commits(repo, number)
      user_client.pull_request_commits(repo, number)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def create_ref(repo, ref, sha)
      user_client.create_ref(repo, ref, sha)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def contents(repo, path, ref = nil, raw_exceptions = false)
      if ref
        user_client.contents(repo, :path => path, :query => { :ref => ref })
      else
        user_client.contents(repo, :path => path)
      end
    rescue *GITHUB_EXCEPTION => exception
      raise exception if raw_exceptions

      handle_octokit_exceptions(exception)
    end

    private

    def user_client
      @user_client ||= Octokit::Client.new(:access_token => @token,
                                           :auto_paginate => AUTO_PAGINATE)
    end

    def app_client
      @app_client ||= Octokit::Client.new(
        client_id: github_client_id,
        client_secret: github_client_secret
      )
    end

    def github_client_id
      Semaphore::GithubApp::Credentials.github_client_id
    end

    def github_client_secret
      Semaphore::GithubApp::Credentials.github_client_secret
    end

    def handle_octokit_exceptions(exception)
      if exception.instance_of? Octokit::Unauthorized
        raise ::RepoHost::RemoteException::Unauthorized, exception.message
      elsif exception.instance_of? Octokit::NotFound
        raise ::RepoHost::RemoteException::NotFound, exception.message
      elsif exception.instance_of? Octokit::TooManyRequests
        raise ::RepoHost::RemoteException::TooManyRequests, exception.message
      elsif exception.instance_of? Octokit::ServiceUnavailable
        raise ::RepoHost::RemoteException::ServiceUnavailable, exception.message
      elsif exception.instance_of? Octokit::InternalServerError
        raise ::RepoHost::RemoteException::InternalServerError, exception.message
      elsif exception.instance_of? Octokit::Forbidden
        raise ::RepoHost::RemoteException::Unauthorized, exception.message
      elsif exception.instance_of? Octokit::RepositoryUnavailable
        raise ::RepoHost::RemoteException::NotFound, exception.message
      elsif exception.instance_of? Octokit::AccountSuspended
        raise ::RepoHost::RemoteException::NotFound, exception.message
      elsif maximum_number_of_statuses?(exception)
        raise ::RepoHost::RemoteException::MaximumNumberOfStatuses, exception.message
      elsif hook_exists?(exception)
        raise ::RepoHost::RemoteException::HookExistsOnRepository, exception.message
      end
    end

    def maximum_number_of_statuses?(exception)
      exception.instance_of?(Octokit::UnprocessableEntity) &&
        exception.message =~ /This SHA and context has reached the maximum number of statuses/
    end

    def hook_exists?(exception)
      exception.instance_of?(Octokit::UnprocessableEntity) &&
        exception.message =~ /Hook already exists on this repository/
    end

    def repositories_for_owner_type(owner_type)
      repositories = user_client.repositories
      groupped_repositories = repositories.group_by { |repo| repo[:owner][:type] }

      groupped_repositories[owner_type] || []
    end

    def user_repositories
      repositories_for_owner_type(OWNER_TYPE_USER)
    end

    def organizations_and_repositories
      repositories_for_owner_type(OWNER_TYPE_ORGANIZATION)
    end
  end
end
