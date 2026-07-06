module Semaphore::GithubApp
  # Manual re-sync of the GitHub App repository/collaborator cache. Reuses the
  # webhook Sidekiq workers, so their unique locks and rate-limit backoff apply.
  class RepositoryRefresh
    Result = Struct.new(:state, :message)

    # Full refresh scoped to a single organization the caller names. Authorized
    # by the caller's real push access to a repo in that org (their own OAuth
    # token), so it works even when nothing is cached yet.
    def self.full_for_organization(user_id, organization)
      org = normalize_organization(organization)
      return Result.new(:failed, "Enter a GitHub organization name.") unless org

      # Opaque result whether the org has no installation or the caller has no
      # claim to it, so this cannot enumerate other organizations.
      no_access = Result.new(:failed, "The GitHub App has no access to #{org}. Grant access on GitHub first.")

      user = ::User.find_by(:id => user_id)
      return no_access unless user

      github_uid = user&.github_repo_host_account&.github_uid

      # Authorize locally first — a cached collaborator row in the org's
      # installation means the caller already had push there — and fall back to a
      # live GitHub push check only on a cache miss.
      #
      # Tradeoff: the fast path is collaborator-level (a push row on any one repo
      # in the installation), so an outside collaborator who is not an org member
      # passes it, unlike the live fallback which requires org membership. This is
      # an accepted over-broad TRIGGER, not a data gap: it only fans out a re-sync
      # (bounded by the per-(user, org) cooldown and each repo's collaborator
      # lock), and the caller still only sees repos they hold their own row for.
      # Tightening it to membership would need the live scan on every org refresh,
      # since there is no local org-membership signal to check.
      #
      # With USE_GITHUB_APP_TO_CHECK_PERMISSIONS the caller's OAuth token cannot
      # prove repo access and the collaborator cache may be empty, so neither
      # signal can authorize anyone. The flag hands authorization to the App
      # itself; discovery and the refresh workers already run on installation
      # tokens.
      installation = GithubAppInstallation.find_for_organization(org)
      authorized = App.use_github_app_to_check_permissions ||
                   (installation && github_uid && user_collaborates_in?(github_uid, installation)) ||
                   user_has_org_push?(user, org)
      return no_access unless authorized

      installation ||= discover_organization_installation(org)
      return no_access unless installation

      if Repositories::Worker.new.unique_lock_exists?([installation.installation_id])
        return Result.new(:already_running, "A repository sync is already running. Results will appear shortly.")
      end

      refresh_installation(installation)
      Result.new(:started, "Repository sync started for #{org}. This can take a few minutes.")
    end

    def self.targeted(user_id, repository_slug)
      slug = GithubAppInstallation.normalize_slug(repository_slug)
      return Result.new(:failed, "Use the owner/repository format.") unless slug

      # Identical opaque result whether the installation is missing or the caller
      # simply has no claim to it, so this endpoint cannot be used to enumerate
      # the repositories/installations of other organizations.
      no_access = Result.new(:failed, "The GitHub App has no access to #{slug}. Grant access on GitHub first.")

      user = ::User.find_by(:id => user_id)
      github_uid = user&.github_repo_host_account&.github_uid
      return no_access unless github_uid

      # Already listed means the user already has access — nothing to fetch, and
      # short-circuiting avoids a synchronous GitHub collaborator re-sync.
      return Result.new(:done, "Repository #{slug} is already in your list.") if listed_for?(github_uid, slug)

      if App.use_github_app_to_check_permissions
        targeted_with_app_token(user, slug)
      else
        targeted_with_oauth_token(user, slug, no_access)
      end
    end

    # Fetch a single repository, cache it, and sync its collaborators. Returns a
    # status symbol for RepositoryRefresh::Worker to log / retry on.
    def self.fetch_and_cache_repository(installation_id, slug)
      token, _expires_at = Token.installation_token(installation_id)
      return :no_token unless token

      client = RepoHost::Github::Client.new(token)
      return :low_rate_limit if client.rate_limit_remaining < App.collaborators_api_rate_limit

      repository = client.repository(slug)

      # Cache the single repo (additive upsert; keeps repositories_count correct)
      # without the async collaborator worker — we sync collaborators inline next.
      Hook.add_repositories(
        installation_id,
        [{ "id" => repository.id, "slug" => repository.full_name }],
        :sync_collaborators => false
      )

      Collaborators.refresh(repository.full_name, repository.id)
    rescue RepoHost::RemoteException::NotFound
      # A repo-scoped installation token 404s for repositories it cannot see.
      :no_repository
    end

    # Reconcile the repo list, then re-sync collaborators for every cached repo too:
    # access can change with no repo-list change, which a manual refresh must reflect.
    # Collaborators::Worker's per-slug lock dedupes any overlap with the delta path.
    def self.refresh_installation(installation)
      Repositories::Worker.perform_async(installation.installation_id)

      installation.installation_repositories.find_each do |repository|
        Collaborators::Worker.perform_in(10, repository.slug, repository.remote_id)
      end
    end
    private_class_method :refresh_installation

    # Whether the repository already shows up in this user's list — i.e. they
    # hold a (push-access) collaborator row for it. Mirrors how #get_repositories
    # builds the list, so "listed" here means exactly "listed in the UI".
    def self.listed_for?(github_uid, slug)
      canonical = GithubAppInstallation.canonical_slug(slug)
      GithubAppCollaborator.where(:c_id => github_uid).where("LOWER(r_name) = ?", canonical).exists?
    end
    private_class_method :listed_for?

    # Installation-scoped: authorizes full / per-organization refresh only (whole-
    # installation re-sync, returns no per-repo data). Targeted per-repo refresh
    # does NOT use this — it requires push to the named repo.
    def self.user_collaborates_in?(github_uid, installation)
      GithubAppCollaborator.exists?(:c_id => github_uid, :installation_id => installation.installation_id)
    end
    private_class_method :user_collaborates_in?

    # Authorize on push to THIS repo: the caller's own OAuth token first, then
    # the GitHub App — but only for callers already cached as collaborators in
    # the slug owner's installation, so unproven probes never spend
    # installation tokens or persist installation rows.
    def self.targeted_with_oauth_token(user, slug, no_access)
      if user_has_github_push?(user, slug)
        # A cached repo definitely covers the slug; otherwise ask GitHub which
        # installation owns it (app JWT). Never reuse another cached org
        # installation — on a selected-repos app it may not cover the slug and
        # the worker would 404 silently.
        installation = GithubAppInstallation.find_for_repository(slug) ||
                       discover_installation(slug)
        return no_access unless installation

        return start_targeted_refresh(installation, slug)
      end

      # The fallback's permission check already proved this installation covers
      # the slug — reuse it; re-discovery could transiently fail and falsely
      # deny access just proven.
      installation = app_granted_installation(user, slug)
      return cannot_verify_access(slug) unless installation

      start_targeted_refresh(installation, slug)
    end
    private_class_method :targeted_with_oauth_token

    # USE_GITHUB_APP_TO_CHECK_PERMISSIONS path: the App token is the only
    # authority on push. Resolving the installation first persists a row
    # before push is proven — accepted behind the operator flag. All denials
    # share one message so the reply can't reveal which repos the app covers.
    def self.targeted_with_app_token(user, slug)
      account = github_account(user)
      return cannot_verify_access(slug) unless account

      installation = GithubAppInstallation.find_for_repository(slug) ||
                     discover_installation(slug)
      return cannot_verify_access(slug) unless installation
      return cannot_verify_access(slug) unless app_confirms_push?(installation, slug, account)

      start_targeted_refresh(installation, slug)
    end
    private_class_method :targeted_with_app_token

    # DB precondition, no GitHub calls: the caller must already hold a
    # collaborator row in the slug owner's installation (one installation per
    # account; cached only, no discovery). Returns the installation whose
    # token confirmed push, nil when access could not be proven.
    def self.app_granted_installation(user, slug)
      account = github_account(user)
      return unless account

      installation = GithubAppInstallation.find_for_organization(slug.split("/").first)
      return unless installation
      return unless user_collaborates_in?(account.github_uid, installation)

      installation if app_confirms_push?(installation, slug, account)
    end
    private_class_method :app_granted_installation

    # Push check with the App's installation token. The reported user must
    # match the stored uid so a stale or reassigned login can't inherit
    # someone else's permission. GitHub folds maintain -> write and
    # triage -> read, so admin/write is exactly "can push". Fails closed on
    # any GitHub error, HTTP (RemoteException) or transport (Faraday/Excon).
    def self.app_confirms_push?(installation, slug, account)
      token, _expires_at = Token.installation_token(installation.installation_id)
      return false unless token

      response = RepoHost::Github::Client.new(token).permission_level(slug, account.login)
      return false unless response&.user&.id.to_s == account.github_uid.to_s

      granted = %w[admin write].include?(response.permission.to_s)
      Rails.logger.info("[RepositoryRefresh] App-token permission for '#{slug}': #{response.permission}")
      granted
    rescue RepoHost::RemoteException, Faraday::Error, Excon::Error => e
      Rails.logger.info("[RepositoryRefresh] App-token permission check failed for '#{slug}': #{e.class}")
      false
    end
    private_class_method :app_confirms_push?

    # Real (non-synthetic) GitHub account with a queryable identity; the login
    # shape guard keeps interpolated API paths safe, mirroring normalize_slug.
    def self.github_account(user)
      account = user&.repo_host_account(::Repository::GITHUB_PROVIDER)
      return unless account
      return if account.github_uid.blank?
      return unless account.login.to_s.match?(/\A[A-Za-z0-9][A-Za-z0-9_-]{0,38}\z/)

      account
    end
    private_class_method :github_account

    # One message for every caller-access denial (precondition miss, missing
    # token, uid mismatch, non-push permission, GitHub errors), so the reply
    # cannot be used to probe which failure occurred.
    def self.cannot_verify_access(slug)
      owner = slug.split("/").first
      Result.new(
        :failed,
        "Couldn't determine your access to #{slug}. You need to already be recognized as " \
        "a collaborator on one of #{owner}'s repositories to refresh it."
      )
    end
    private_class_method :cannot_verify_access

    # The fetch + collaborator sync always runs in the worker (rate-limited,
    # unique-locked) so it never blocks the request thread — cached or not.
    def self.start_targeted_refresh(installation, slug)
      Worker.perform_async(installation.installation_id, slug)
      Result.new(:started, "Refreshing #{slug} from GitHub. Search again in a moment.")
    end
    private_class_method :start_targeted_refresh

    # Whether the caller has push access to the repo, checked with their own
    # OAuth token (real, non-synthetic account). Connectionless users short-
    # circuit without an API call; fails closed on any GitHub error.
    def self.user_has_github_push?(user, slug)
      account = user&.repo_host_account(::Repository::GITHUB_PROVIDER)
      return false if account&.token.blank?

      repository = RepoHost::Github::Client.new(account.token).repository(slug)
      !!repository.permissions&.push
    rescue RepoHost::RemoteException
      false
    end
    private_class_method :user_has_github_push?

    # Resolve (and persist) the installation that owns a repository when no cached
    # repo reveals it. Only called for an already-authorized caller, so we never
    # create rows for installations the caller cannot reach.
    def self.discover_installation(slug)
      installation_id = Token.repository_installation_id(slug)
      return unless installation_id

      GithubAppInstallation.find_or_create_by!(:installation_id => installation_id)
    rescue StandardError => e
      Rails.logger.error("[RepositoryRefresh] Failed to discover installation for '#{slug}': #{e.message}")
      nil
    end
    private_class_method :discover_installation

    def self.normalize_organization(organization)
      name = organization.to_s.strip
      return unless name.match?(/\A[A-Za-z0-9][A-Za-z0-9-]{0,38}\z/)

      name
    end
    private_class_method :normalize_organization

    # Whether the caller has push access to any repository owned by the org,
    # checked with their own OAuth token. Connectionless users short-circuit;
    # fails closed on any GitHub error.
    def self.user_has_org_push?(user, organization)
      account = user&.repo_host_account(::Repository::GITHUB_PROVIDER)
      return false if account&.token.blank?

      RepoHost::Github::Client.new(account.token).push_access_to_organization?(organization)
    rescue RepoHost::RemoteException
      false
    end
    private_class_method :user_has_org_push?

    # Resolve (and persist) an organization's installation when no cached repo
    # reveals it. Only called for an already-authorized caller, so we never create
    # rows for installations the caller cannot reach.
    def self.discover_organization_installation(organization)
      installation_id = Token.organization_installation_id(organization)
      return unless installation_id

      GithubAppInstallation.find_or_create_by!(:installation_id => installation_id)
    rescue StandardError => e
      Rails.logger.error("[RepositoryRefresh] Failed to discover installation for org '#{organization}': #{e.message}")
      nil
    end
    private_class_method :discover_organization_installation
  end
end
