require "spec_helper"

module Semaphore::GithubApp
  RSpec.describe RepositoryRefresh, :aggregate_failures do
    before do
      Sidekiq::Worker.clear_all
      allow_any_instance_of(Repositories::Worker).to receive(:unique_lock_exists?).and_return(false)
    end

    describe ".full_for_organization" do
      let(:user) { FactoryBot.create(:user, :github_connection) }
      let!(:installation) do
        FactoryBot.create(:github_app_installation, :installation_id => 555, :repositories => ["acme/widget"])
      end

      before do
        Sidekiq::Worker.clear_all
        allow_any_instance_of(Repositories::Worker).to receive(:unique_lock_exists?).and_return(false)
      end

      it "rejects a blank or malformed organization without calling GitHub" do
        expect_any_instance_of(RepoHost::Github::Client).not_to receive(:push_access_to_organization?)

        result = described_class.full_for_organization(user.id, "not a valid org!")

        expect(result.state).to eq(:failed)
        expect(result.message).to match(/organization name/)
        expect(Repositories::Worker.jobs).to be_empty
      end

      it "authorizes via a cached collaborator row without calling GitHub" do
        GithubAppCollaborator.create!(
          :c_id => user.github_repo_host_account.github_uid,
          :c_name => "user",
          :r_name => "acme/widget",
          :installation_id => installation.installation_id
        )
        expect_any_instance_of(RepoHost::Github::Client).not_to receive(:push_access_to_organization?)

        result = described_class.full_for_organization(user.id, "acme")

        expect(result.state).to eq(:started)
        expect(Repositories::Worker.jobs.map { |job| job["args"] }).to eq([[installation.installation_id]])
      end

      context "when the caller has push access in the org" do
        before do
          allow_any_instance_of(RepoHost::Github::Client)
            .to receive(:push_access_to_organization?).with("acme").and_return(true)
        end

        it "starts a refresh for the org's cached installation" do
          result = described_class.full_for_organization(user.id, "acme")

          expect(result.state).to eq(:started)
          expect(result.message).to include("acme")
          expect(Repositories::Worker.jobs.map { |job| job["args"] }).to eq([[installation.installation_id]])
        end

        it "re-syncs collaborators for every already-cached repository" do
          installation.add_repositories!([{ "id" => 77, "slug" => "acme/another" }])
          expected = installation.installation_repositories.map { |repo| [repo.slug, repo.remote_id] }

          described_class.full_for_organization(user.id, "acme")

          expect(expected).not_to be_empty
          expect(Collaborators::Worker.jobs.map { |job| job["args"] }).to match_array(expected)
        end

        it "discovers the installation via app JWT when the org has no cached repos" do
          allow(GithubAppInstallation).to receive(:find_for_organization).with("acme").and_return(nil)
          allow(Semaphore::GithubApp::Token).to receive(:organization_installation_id).with("acme").and_return(9090)

          result = described_class.full_for_organization(user.id, "acme")

          expect(result.state).to eq(:started)
          expect(GithubAppInstallation.exists?(:installation_id => 9090)).to be(true)
          expect(Repositories::Worker.jobs.map { |job| job["args"] }).to eq([[9090]])
        end

        it "fails when the app is not installed on the org" do
          allow(GithubAppInstallation).to receive(:find_for_organization).with("acme").and_return(nil)
          allow(Semaphore::GithubApp::Token).to receive(:organization_installation_id).and_return(nil)

          result = described_class.full_for_organization(user.id, "acme")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Grant access on GitHub first/)
          expect(Repositories::Worker.jobs).to be_empty
        end

        it "reports already running when the installation is locked" do
          allow_any_instance_of(Repositories::Worker).to receive(:unique_lock_exists?).and_return(true)

          result = described_class.full_for_organization(user.id, "acme")

          expect(result.state).to eq(:already_running)
          expect(Repositories::Worker.jobs).to be_empty
        end
      end

      context "when the caller lacks push access in the org" do
        before do
          allow_any_instance_of(RepoHost::Github::Client).to receive(:push_access_to_organization?).and_return(false)
        end

        it "refuses without enqueuing or discovering an installation" do
          expect(Semaphore::GithubApp::Token).not_to receive(:organization_installation_id)

          result = described_class.full_for_organization(user.id, "acme")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Grant access on GitHub first/)
          expect(Repositories::Worker.jobs).to be_empty
        end
      end

      context "when the caller has no GitHub connection" do
        let(:user_without_github) { FactoryBot.create(:user) }

        it "refuses without a GitHub call" do
          expect_any_instance_of(RepoHost::Github::Client).not_to receive(:push_access_to_organization?)

          result = described_class.full_for_organization(user_without_github.id, "acme")

          expect(result.state).to eq(:failed)
          expect(Repositories::Worker.jobs).to be_empty
        end
      end

      context "when USE_GITHUB_APP_TO_CHECK_PERMISSIONS is set" do
        before do
          allow(App).to receive(:use_github_app_to_check_permissions).and_return(true)
        end

        it "authorizes without an OAuth scan or cached collaborator rows" do
          expect_any_instance_of(RepoHost::Github::Client).not_to receive(:push_access_to_organization?)

          result = described_class.full_for_organization(user.id, "acme")

          expect(result.state).to eq(:started)
          expect(Repositories::Worker.jobs.map { |job| job["args"] }).to eq([[installation.installation_id]])
        end

        it "discovers the installation via app JWT when the org has no cached repos" do
          allow(GithubAppInstallation).to receive(:find_for_organization).with("acme").and_return(nil)
          allow(Semaphore::GithubApp::Token).to receive(:organization_installation_id).with("acme").and_return(9090)

          result = described_class.full_for_organization(user.id, "acme")

          expect(result.state).to eq(:started)
          expect(Repositories::Worker.jobs.map { |job| job["args"] }).to eq([[9090]])
        end

        it "fails when the app is not installed on the org" do
          allow(GithubAppInstallation).to receive(:find_for_organization).with("acme").and_return(nil)
          allow(Semaphore::GithubApp::Token).to receive(:organization_installation_id).and_return(nil)

          result = described_class.full_for_organization(user.id, "acme")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Grant access on GitHub first/)
          expect(Repositories::Worker.jobs).to be_empty
        end

        it "still rejects a malformed organization without enqueuing" do
          result = described_class.full_for_organization(user.id, "not a valid org!")

          expect(result.state).to eq(:failed)
          expect(Repositories::Worker.jobs).to be_empty
        end

        it "still reports already running when the installation is locked" do
          allow_any_instance_of(Repositories::Worker).to receive(:unique_lock_exists?).and_return(true)

          result = described_class.full_for_organization(user.id, "acme")

          expect(result.state).to eq(:already_running)
          expect(Repositories::Worker.jobs).to be_empty
        end

        it "refuses an unknown user id without enqueuing" do
          result = described_class.full_for_organization(SecureRandom.uuid, "acme")

          expect(result.state).to eq(:failed)
          expect(Repositories::Worker.jobs).to be_empty
        end
      end
    end

    describe ".targeted" do
      let!(:installation) { FactoryBot.create(:github_app_installation) }
      let(:user) { FactoryBot.create(:user, :github_connection) }
      let(:github_uid) { user.github_repo_host_account.github_uid }

      # An installation-level collaborator row on a repo OTHER than the one
      # under test. A row unlocks the App-token per-repo check (skipping
      # OAuth) but never grants access by itself — the App reports the
      # caller's real permission.
      def authorize(user_uid, installation_record, repo: "semaphoreio/semaphore")
        GithubAppCollaborator.create!(
          :c_id => user_uid,
          :c_name => "user",
          :r_name => repo,
          :installation_id => installation_record.installation_id
        )
      end

      # OAuth fallback authorizes on live push to the named repo. Stubs the
      # check (RepoHost::Github::Client#repository.permissions.push).
      def repo_with_push(value)
        Struct.new(:permissions).new(Struct.new(:push).new(value))
      end

      # Response of the app-token permission check
      # (RepoHost::Github::Client#permission_level).
      def permission_response(permission, uid)
        Struct.new(:permission, :user).new(permission, Struct.new(:id).new(uid))
      end

      before { authorize(github_uid, installation) }

      it "rejects input that is not an owner/repository slug" do
        result = described_class.targeted(user.id, "not a slug")

        expect(result.state).to eq(:failed)
        expect(result.message).to match(%r{owner/repository})
      end

      context "when the repository is already listed for the caller" do
        before do
          GithubAppCollaborator.create!(
            :c_id => github_uid,
            :c_name => "user",
            :r_name => "renderedtext/guard",
            :installation_id => installation.installation_id
          )
        end

        it "short-circuits to done without calling GitHub or enqueuing a sync" do
          allow(Collaborators).to receive(:refresh)

          result = described_class.targeted(user.id, "RenderedText/Guard")

          expect(result.state).to eq(:done)
          expect(result.message).to match(/already in your list/)
          expect(Collaborators).not_to have_received(:refresh)
          expect(Repositories::Worker.jobs).to be_empty
        end
      end

      # A cached installation covers the slug's owner and the caller holds a
      # collaborator row in it (outer before), so the App token settles the
      # permission check directly — the caller's own OAuth token is never
      # used on this path.
      context "when a cached installation covers the owner" do
        before do
          allow(Semaphore::GithubApp::Token).to receive(:installation_token)
            .with(installation.installation_id)
            .and_return(["app-token", Time.zone.now + 3600])
        end

        def stub_permission(response, slug: "renderedtext/guard")
          allow_any_instance_of(RepoHost::Github::Client).to receive(:permission_level)
            .with(slug, user.github_repo_host_account.login)
            .and_return(response)
        end

        it "starts the refresh without an OAuth call when the app reports write permission" do
          stub_permission(permission_response("write", github_uid))
          expect_any_instance_of(RepoHost::Github::Client).not_to receive(:repository)

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:started)
          expect(described_class::Worker.jobs.map { |job| job["args"] })
            .to eq([[installation.installation_id, "renderedtext/guard"]])
        end

        it "starts the refresh when the app reports admin permission" do
          stub_permission(permission_response("admin", github_uid))

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:started)
        end

        it "uses the owner's installation for an uncached repository without discovery" do
          stub_permission(permission_response("write", github_uid), :slug => "renderedtext/uncached-repo")
          expect(Semaphore::GithubApp::Token).not_to receive(:repository_installation_id)

          result = described_class.targeted(user.id, "renderedtext/uncached-repo")

          expect(result.state).to eq(:started)
          expect(described_class::Worker.jobs.map { |job| job["args"] })
            .to eq([[installation.installation_id, "renderedtext/uncached-repo"]])
        end

        it "defers the GitHub fetch and cache write to the background worker" do
          allow(Collaborators).to receive(:refresh)
          stub_permission(permission_response("write", github_uid), :slug => "renderedtext/brand-new-repo")

          described_class.targeted(user.id, "renderedtext/brand-new-repo")

          expect(installation.installation_repositories.exists?(:slug => "renderedtext/brand-new-repo")).to be(false)
          expect(described_class::Worker.jobs).not_to be_empty
          expect(Collaborators).not_to have_received(:refresh)
        end

        # Cross-tenant regression: a collaborator row elsewhere in the
        # installation (outer before) must not authorize a repo the caller
        # cannot push to — the App reports their real permission.
        it "refuses when the app reports read-only permission" do
          stub_permission(permission_response("read", github_uid))

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Couldn't determine your access/)
          expect(described_class::Worker.jobs).to be_empty
        end

        it "refuses when the reported GitHub user does not match the stored uid" do
          stub_permission(permission_response("admin", 999_999_999))

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(described_class::Worker.jobs).to be_empty
        end

        # Selected-repos regression: the org installation is cached but does
        # not cover the slug — the scoped token 404s and we fail closed rather
        # than enqueue a worker that would 404 silently.
        it "refuses when the installation cannot see the repository" do
          allow_any_instance_of(RepoHost::Github::Client).to receive(:permission_level)
            .and_raise(RepoHost::RemoteException::NotFound)

          result = described_class.targeted(user.id, "renderedtext/uncovered")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Couldn't determine your access/)
          expect(described_class::Worker.jobs).to be_empty
        end

        it "fails closed when GitHub rate-limits the check" do
          allow_any_instance_of(RepoHost::Github::Client).to receive(:permission_level)
            .and_raise(RepoHost::RemoteException::TooManyRequests)

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(described_class::Worker.jobs).to be_empty
        end

        it "fails closed when the permission check cannot reach GitHub" do
          allow_any_instance_of(RepoHost::Github::Client).to receive(:permission_level)
            .and_raise(Faraday::ConnectionFailed)

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Couldn't determine your access/)
          expect(described_class::Worker.jobs).to be_empty
        end

        it "fails closed when the token mint cannot reach GitHub" do
          allow(Semaphore::GithubApp::Token).to receive(:installation_token)
            .and_raise(Excon::Error::Timeout)

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Couldn't determine your access/)
          expect(described_class::Worker.jobs).to be_empty
        end

        it "refuses without a permission check when no installation token is available" do
          allow(Semaphore::GithubApp::Token).to receive(:installation_token).and_return(nil)
          expect_any_instance_of(RepoHost::Github::Client).not_to receive(:permission_level)

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Couldn't determine your access/)
        end

        # A caller with no collaborator row is authorized by their own OAuth
        # token instead; the cached installation is still reused for the fetch.
        it "authorizes a rowless caller via OAuth and reuses the cached installation" do
          rowless = FactoryBot.create(:user, :github_connection)
          allow_any_instance_of(RepoHost::Github::Client).to receive(:repository)
            .with("renderedtext/guard").and_return(repo_with_push(true))
          expect_any_instance_of(RepoHost::Github::Client).not_to receive(:permission_level)
          expect(Semaphore::GithubApp::Token).not_to receive(:repository_installation_id)

          result = described_class.targeted(rowless.id, "renderedtext/guard")

          expect(result.state).to eq(:started)
          expect(described_class::Worker.jobs.map { |job| job["args"] })
            .to eq([[installation.installation_id, "renderedtext/guard"]])
        end

        # Rowless probes never spend an App token and get the same opaque
        # denial as a missing repository, so the endpoint still cannot be
        # used to enumerate repositories.
        it "refuses an outsider without App calls and with the same message as a missing repository" do
          outsider = FactoryBot.create(:user, :github_connection)
          allow_any_instance_of(RepoHost::Github::Client).to receive(:repository)
            .and_raise(RepoHost::RemoteException::NotFound)
          expect_any_instance_of(RepoHost::Github::Client).not_to receive(:permission_level)
          expect(Semaphore::GithubApp::Token).not_to receive(:installation_token)

          covered = described_class.targeted(outsider.id, "renderedtext/guard")
          missing = described_class.targeted(outsider.id, "ghost-owner/ghost-repo")

          expect(covered.state).to eq(:failed)
          expect(covered.state).to eq(missing.state)
          expect(covered.message).to match(/Couldn't determine your access/)
          expect(missing.message).to match(/Couldn't determine your access/)
          expect(described_class::Worker.jobs).to be_empty
        end
      end

      # No cached installation for the owner: the caller's own OAuth token
      # must prove push to the repo, then app-JWT discovery resolves the
      # installation.
      context "when no cached installation covers the owner" do
        it "authorizes via live push, discovers the installation and enqueues the fetch" do
          allow_any_instance_of(RepoHost::Github::Client).to receive(:repository)
            .with("acme/widget").and_return(repo_with_push(true))
          allow(Semaphore::GithubApp::Token).to receive(:repository_installation_id)
            .with("acme/widget").and_return(777)

          result = described_class.targeted(user.id, "acme/widget")

          expect(result.state).to eq(:started)
          expect(GithubAppInstallation.exists?(:installation_id => 777)).to be(true)
          expect(described_class::Worker.jobs.map { |job| job["args"] })
            .to eq([[777, "acme/widget"]])
        end

        it "refuses when the app is not installed on the repository" do
          allow_any_instance_of(RepoHost::Github::Client).to receive(:repository)
            .and_return(repo_with_push(true))
          allow(Semaphore::GithubApp::Token).to receive(:repository_installation_id).and_return(nil)

          result = described_class.targeted(user.id, "acme/widget")

          expect(result.state).to eq(:failed)
          expect(described_class::Worker.jobs).to be_empty
          expect(GithubAppInstallation.count).to eq(1)
        end

        it "skips discovery and app calls entirely when the caller lacks live push access" do
          allow_any_instance_of(RepoHost::Github::Client).to receive(:repository)
            .and_return(repo_with_push(false))
          expect(Semaphore::GithubApp::Token).not_to receive(:repository_installation_id)
          expect(Semaphore::GithubApp::Token).not_to receive(:installation_token)

          result = described_class.targeted(user.id, "acme/widget")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Couldn't determine your access/)
          expect(described_class::Worker.jobs).to be_empty
        end

        it "refuses when the caller's token cannot see the repository" do
          allow_any_instance_of(RepoHost::Github::Client).to receive(:repository)
            .and_raise(RepoHost::RemoteException::NotFound)

          result = described_class.targeted(user.id, "unknown-owner/repo")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Couldn't determine your access/)
          expect(described_class::Worker.jobs).to be_empty
        end
      end

      context "when the caller has no GitHub connection" do
        let(:user_without_github) { FactoryBot.create(:user) }

        it "is refused without any GitHub call" do
          expect_any_instance_of(RepoHost::Github::Client).not_to receive(:repository)
          expect_any_instance_of(RepoHost::Github::Client).not_to receive(:permission_level)
          expect(Semaphore::GithubApp::Token).not_to receive(:installation_token)

          result = described_class.targeted(user_without_github.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Couldn't determine your access/)
          expect(Repositories::Worker.jobs).to be_empty
        end
      end

      context "when USE_GITHUB_APP_TO_CHECK_PERMISSIONS is set" do
        before do
          allow(App).to receive(:use_github_app_to_check_permissions).and_return(true)
          allow(Semaphore::GithubApp::Token).to receive(:installation_token)
            .and_return(["app-token", Time.zone.now + 3600])
        end

        def stub_permission_for(account, slug, response)
          allow_any_instance_of(RepoHost::Github::Client).to receive(:permission_level)
            .with(slug, account.login).and_return(response)
        end

        it "authorizes with the app token without consulting the caller's own token" do
          expect_any_instance_of(RepoHost::Github::Client).not_to receive(:repository)
          stub_permission_for(user.github_repo_host_account, "renderedtext/guard",
                              permission_response("write", github_uid))

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:started)
          expect(described_class::Worker.jobs.map { |job| job["args"] })
            .to eq([[installation.installation_id, "renderedtext/guard"]])
        end

        it "authorizes a caller with no cached collaborator rows" do
          newcomer = FactoryBot.create(:user, :github_connection)
          account = newcomer.github_repo_host_account
          stub_permission_for(account, "renderedtext/guard",
                              permission_response("write", account.github_uid))

          result = described_class.targeted(newcomer.id, "renderedtext/guard")

          expect(result.state).to eq(:started)
        end

        it "discovers the installation for an uncached repository" do
          allow(Semaphore::GithubApp::Token).to receive(:repository_installation_id)
            .with("acme/widget").and_return(777)
          stub_permission_for(user.github_repo_host_account, "acme/widget",
                              permission_response("write", github_uid))

          result = described_class.targeted(user.id, "acme/widget")

          expect(result.state).to eq(:started)
          expect(described_class::Worker.jobs.map { |job| job["args"] }).to eq([[777, "acme/widget"]])
        end

        it "refuses when the app is not installed on the repository" do
          allow(Semaphore::GithubApp::Token).to receive(:repository_installation_id).and_return(nil)

          result = described_class.targeted(user.id, "acme/widget")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Couldn't determine your access/)
          expect(described_class::Worker.jobs).to be_empty
        end

        it "gives callers no signal distinguishing an uncovered repository from denied permission" do
          allow(Semaphore::GithubApp::Token).to receive(:repository_installation_id).and_return(nil)
          uncovered = described_class.targeted(user.id, "ghost-owner/ghost-repo")

          stub_permission_for(user.github_repo_host_account, "renderedtext/guard",
                              permission_response("read", github_uid))
          denied = described_class.targeted(user.id, "renderedtext/guard")

          expect(uncovered.state).to eq(:failed)
          expect(denied.state).to eq(:failed)
          expect(uncovered.message).to match(/Couldn't determine your access/)
          expect(denied.message).to match(/Couldn't determine your access/)
        end

        it "refuses when the app reports read-only permission" do
          stub_permission_for(user.github_repo_host_account, "renderedtext/guard",
                              permission_response("read", github_uid))

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Couldn't determine your access/)
          expect(described_class::Worker.jobs).to be_empty
        end

        it "refuses a caller without a real GitHub account before any GitHub call" do
          no_github = FactoryBot.create(:user)
          expect(Semaphore::GithubApp::Token).not_to receive(:repository_installation_id)
          expect(Semaphore::GithubApp::Token).not_to receive(:installation_token)

          result = described_class.targeted(no_github.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Couldn't determine your access/)
        end

        it "short-circuits to done when the repository is already listed" do
          GithubAppCollaborator.create!(
            :c_id => github_uid,
            :c_name => "user",
            :r_name => "renderedtext/guard",
            :installation_id => installation.installation_id
          )
          expect_any_instance_of(RepoHost::Github::Client).not_to receive(:permission_level)

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:done)
        end
      end
    end

    describe ".fetch_and_cache_repository" do
      let!(:installation) { FactoryBot.create(:github_app_installation) }
      let(:remote_repository) { Struct.new(:id, :full_name).new(555, "renderedtext/brand-new-repo") }

      before do
        allow(Semaphore::GithubApp::Token).to receive(:installation_token)
          .and_return(["tok", Time.zone.now + 3600])
        allow_any_instance_of(RepoHost::Github::Client).to receive(:rate_limit_remaining)
          .and_return(1_000_000)
      end

      it "caches the single repository and syncs its collaborators" do
        allow_any_instance_of(RepoHost::Github::Client).to receive(:repository)
          .with("renderedtext/brand-new-repo").and_return(remote_repository)
        allow(Collaborators).to receive(:refresh).and_return(:ok)

        result = described_class.fetch_and_cache_repository(installation.installation_id, "renderedtext/brand-new-repo")

        expect(result).to eq(:ok)
        expect(Collaborators).to have_received(:refresh).with("renderedtext/brand-new-repo", 555)
        expect(installation.installation_repositories.exists?(:slug => "renderedtext/brand-new-repo")).to be(true)
      end

      it "returns :no_repository without caching when the installation cannot access it" do
        allow_any_instance_of(RepoHost::Github::Client).to receive(:repository)
          .and_raise(RepoHost::RemoteException::NotFound)
        allow(Collaborators).to receive(:refresh)

        result = described_class.fetch_and_cache_repository(installation.installation_id, "renderedtext/brand-new-repo")

        expect(result).to eq(:no_repository)
        expect(Collaborators).not_to have_received(:refresh)
        expect(installation.installation_repositories.exists?(:slug => "renderedtext/brand-new-repo")).to be(false)
      end

      it "returns :low_rate_limit without calling GitHub when the rate limit is too low" do
        allow_any_instance_of(RepoHost::Github::Client).to receive(:rate_limit_remaining).and_return(0)
        expect_any_instance_of(RepoHost::Github::Client).not_to receive(:repository)

        result = described_class.fetch_and_cache_repository(installation.installation_id, "renderedtext/brand-new-repo")

        expect(result).to eq(:low_rate_limit)
      end

      it "returns :no_token when no installation token is available" do
        allow(Semaphore::GithubApp::Token).to receive(:installation_token).and_return(nil)

        result = described_class.fetch_and_cache_repository(installation.installation_id, "renderedtext/brand-new-repo")

        expect(result).to eq(:no_token)
      end
    end

    context "when DISABLE_COLLABORATOR_WEBHOOK_SYNC is set" do
      before do
        allow(App).to receive(:disable_collaborator_webhook_sync).and_return(true)
      end

      it "still enqueues the repository sync — manual refresh is not gated by the env flag" do
        user = FactoryBot.create(:user, :github_connection)
        installation = FactoryBot.create(:github_app_installation, :repositories => ["acme/widget"])
        GithubAppCollaborator.create!(
          :c_id => user.github_repo_host_account.github_uid,
          :c_name => "user",
          :r_name => "acme/widget",
          :installation_id => installation.installation_id
        )

        result = described_class.full_for_organization(user.id, "acme")

        expect(result.state).to eq(:started)
        expect(Repositories::Worker.jobs.map { |job| job["args"] })
          .to eq([[installation.installation_id]])
      end
    end
  end
end
