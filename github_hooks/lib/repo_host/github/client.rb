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
    ORG_PUSH_SCAN_MAX_PAGES = 10
    ORG_PUSH_OPEN_TIMEOUT = 5
    ORG_PUSH_READ_TIMEOUT = 10

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
    rescue Octokit::ServiceUnavailable, Octokit::InternalServerError,
           Octokit::TooManyRequests => exception
      # Transient upstream failures (5xx, rate limits) must not classify the
      # token as revoked; raising keeps the caller's revoke status unchanged.
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

    # True if the token owner is an ORGANIZATION MEMBER with push access to at
    # least one repository owned by the org. Pages /user/repos with the
    # organization_member affiliation only — outside collaborators (who are not
    # members) are excluded — early exit, bounded by ORG_PUSH_SCAN_MAX_PAGES.
    def push_access_to_organization?(organization)
      target = organization.to_s.downcase
      client = Octokit::Client.new(
        :access_token => @token,
        :auto_paginate => false,
        :connection_options => {
          :request => { :open_timeout => ORG_PUSH_OPEN_TIMEOUT, :timeout => ORG_PUSH_READ_TIMEOUT }
        }
      )

      ORG_PUSH_SCAN_MAX_PAGES.times do |index|
        repos = client.repos(nil, :affiliation => "organization_member",
                                  :per_page => 100, :page => index + 1)
        return false if repos.empty?
        return true if repos.any? { |repo| organization_push?(repo, target) }
        return false if repos.size < 100
      end

      Rails.logger.warn("[RepoHost::Github::Client] org push scan hit page cap for organization=#{organization}")
      false
    rescue Faraday::Error => exception
      # A slow/hung GitHub call must not occupy the request thread past the
      # per-request timeout: fail closed (treat as no push access).
      Rails.logger.warn("[RepoHost::Github::Client] org push scan failed for organization=#{organization}: #{exception.class}")
      false
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

    def compare(repo, base, head)
      # We only read the first-page envelope of the comparison (`base_commit`).
      # The `commits[]`/`files[]` lists are never used, so route this through a
      # non-paginating client: with auto-pagination a SHA far behind the branch
      # head would make Octokit walk every intermediate commit page, *increasing*
      # rate-limit usage (the opposite of this call's intent). A dedicated
      # memoized client is used rather than toggling `user_client.auto_paginate`,
      # which would race other callers of the shared client.
      #
      # `base`/`head` are interpolated into the URL path unescaped by Octokit, so
      # escape them per `/`-segment to keep branch names with URL-significant
      # characters (e.g. `feat#1`) working while preserving namespace slashes.
      non_paginating_client.compare(repo, escape_ref(base), escape_ref(head))
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def collaborators(repo)
      user_client.collaborators(repo)
    rescue *GITHUB_EXCEPTION => exception
      handle_octokit_exceptions(exception)
    end

    def permission_level(repo, username)
      user_client.permission_level(repo, username)
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

    def organization_push?(repo, target_login)
      owner = repo[:owner]
      owner &&
        owner[:type] == OWNER_TYPE_ORGANIZATION &&
        owner[:login].to_s.downcase == target_login &&
        repo[:permissions] && !!repo[:permissions][:push]
    end

    def user_client
      @user_client ||= Octokit::Client.new(:access_token => @token,
                                           :auto_paginate => AUTO_PAGINATE)
    end

    # Like `user_client`, but with auto-pagination disabled. For calls that only
    # need first-page envelope fields (e.g. `compare`'s `base_commit`) and must
    # not fan out across paginated array fields.
    def non_paginating_client
      @non_paginating_client ||= Octokit::Client.new(:access_token => @token,
                                                     :auto_paginate => false)
    end

    # Escapes a git ref for safe interpolation into a URL path segment, leaving
    # the `/` separators that delimit nested branch namespaces intact.
    def escape_ref(ref)
      ref.to_s.split("/").map { |segment| CGI.escape(segment) }.join("/")
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
      elsif ref_already_exists?(exception)
        raise ::RepoHost::RemoteException::ReferenceAlreadyExists, exception.message
      else
        raise ::RepoHost::RemoteException::Unknown, exception.message
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

    def ref_already_exists?(exception)
      exception.instance_of?(Octokit::UnprocessableEntity) &&
        exception.message =~ /Reference already exists/
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
