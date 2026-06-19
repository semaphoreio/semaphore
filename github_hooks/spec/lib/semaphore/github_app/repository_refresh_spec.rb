require "spec_helper"

module Semaphore::GithubApp
  RSpec.describe RepositoryRefresh, :aggregate_failures do
    before do
      Sidekiq::Worker.clear_all
      allow_any_instance_of(Repositories::Worker).to receive(:unique_lock_exists?).and_return(false)
    end

    describe ".full" do
      let(:user) { FactoryBot.create(:user, :github_connection) }
      let(:github_uid) { user.github_repo_host_account.github_uid }

      def link_user_to(installation)
        GithubAppCollaborator.create!(
          :c_id => github_uid,
          :c_name => "user",
          :r_name => "renderedtext/guard",
          :installation_id => installation.installation_id
        )
      end

      context "when the user is not a collaborator on any installation" do
        before { FactoryBot.create(:github_app_installation) }

        it "fails and enqueues nothing" do
          result = described_class.full(user.id)

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Install the GitHub App/)
          expect(Repositories::Worker.jobs).to be_empty
        end
      end

      context "when the requesting user cannot be resolved" do
        it "fails without issuing a query for a nil github uid" do
          # github_repo_host_account falls back to a synthetic account for existing
          # users, so a nil uid only happens when the user_id resolves to nothing.
          # c_id is NOT NULL, so where(c_id: nil) would match nothing anyway — but
          # we should not run the query at all.
          ghost = FactoryBot.create(:user)
          ghost_id = ghost.id
          ghost.destroy

          expect(GithubAppCollaborator).not_to receive(:where)

          result = described_class.full(ghost_id)

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Install the GitHub App/)
          expect(Repositories::Worker.jobs).to be_empty
        end
      end

      context "when the user's only installation is suspended" do
        before do
          installation = FactoryBot.create(:github_app_installation, :suspended_at => Time.zone.now)
          link_user_to(installation)
        end

        it "fails and enqueues nothing" do
          result = described_class.full(user.id)

          expect(result.state).to eq(:failed)
          expect(Repositories::Worker.jobs).to be_empty
        end
      end

      context "when the user's installations are already being synced" do
        before do
          installation = FactoryBot.create(:github_app_installation)
          link_user_to(installation)
          allow_any_instance_of(Repositories::Worker).to receive(:unique_lock_exists?).and_return(true)
        end

        it "reports the sync as already running without enqueueing" do
          result = described_class.full(user.id)

          expect(result.state).to eq(:already_running)
          expect(Repositories::Worker.jobs).to be_empty
          expect(Collaborators::Worker.jobs).to be_empty
        end
      end

      context "with the user's free installations" do
        let!(:installation) { FactoryBot.create(:github_app_installation) }

        before { link_user_to(installation) }

        it "refreshes only installations the user collaborates in" do
          # An installation the user is NOT linked to must be left untouched.
          FactoryBot.create(:github_app_installation, :installation_id => 999,
                                                      :repositories => ["acme/anvil"])

          result = described_class.full(user.id)

          expect(result.state).to eq(:started)
          expect(Repositories::Worker.jobs.map { |job| job["args"] })
            .to eq([[installation.installation_id]])
        end

        it "enqueues no collaborator workers directly" do
          described_class.full(user.id)

          expect(Collaborators::Worker.jobs).to be_empty
          expect(Repositories::Worker.jobs.map { |job| job["args"] })
            .to eq([[installation.installation_id]])
        end
      end
    end

    describe ".targeted" do
      let!(:installation) { FactoryBot.create(:github_app_installation) }
      let(:user) { FactoryBot.create(:user, :github_connection) }
      let(:github_uid) { user.github_repo_host_account.github_uid }

      # Grant the caller installation-level access via a repo other than the one
      # under test, so the cached-repo specs still reach the real collaborator
      # re-sync. Listing them on the target repo would instead trigger the
      # already-listed short-circuit.
      def authorize(user_uid, installation_record, repo: "semaphoreio/semaphore")
        GithubAppCollaborator.create!(
          :c_id => user_uid,
          :c_name => "user",
          :r_name => repo,
          :installation_id => installation_record.installation_id
        )
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

      context "when the repository is cached" do
        it "refreshes collaborators with the stored slug and remote id" do
          allow(Collaborators).to receive(:refresh).and_return(:ok)

          result = described_class.targeted(user.id, "RenderedText/Guard")

          expect(Collaborators).to have_received(:refresh).with("renderedtext/guard", 0)
          expect(result.state).to eq(:done)
          expect(result.message).to include("renderedtext/guard")
        end

        it "maps :no_token to a failure about app access" do
          allow(Collaborators).to receive(:refresh).and_return(:no_token)

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/no access/)
        end

        it "maps :no_repository to a failure about the repository" do
          allow(Collaborators).to receive(:refresh).and_return(:no_repository)

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/not found on GitHub/)
        end

        it "maps :low_rate_limit to a retry-later failure" do
          allow(Collaborators).to receive(:refresh).and_return(:low_rate_limit)

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/rate limit/)
        end

        it "fails without calling refresh when the cached row is gone" do
          empty_installation = FactoryBot.create(
            :github_app_installation,
            :installation_id => 4242,
            :repositories => ["other/repo"]
          )
          authorize(github_uid, empty_installation)
          allow(GithubAppInstallation).to receive(:find_for_repository).and_return(empty_installation)
          allow(Collaborators).to receive(:refresh)

          result = described_class.targeted(user.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/no longer available/)
          expect(Collaborators).not_to have_received(:refresh)
        end
      end

      context "when the repository is not cached" do
        it "re-syncs the owner's installation repository list" do
          result = described_class.targeted(user.id, "renderedtext/brand-new-repo")

          expect(result.state).to eq(:started)
          expect(Repositories::Worker.jobs.map { |job| job["args"] })
            .to eq([[installation.installation_id]])
        end

        it "reports an already running sync for the owner's installation" do
          allow_any_instance_of(Repositories::Worker).to receive(:unique_lock_exists?).and_return(true)

          result = described_class.targeted(user.id, "renderedtext/brand-new-repo")

          expect(result.state).to eq(:already_running)
          expect(Repositories::Worker.jobs).to be_empty
        end

        it "fails when no installation covers the owner" do
          result = described_class.targeted(user.id, "unknown-owner/repo")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/no access/)
        end
      end

      # Regression for the cross-tenant authorization gap: a targeted refresh
      # must be scoped to the requesting user, not to anyone who can reach the
      # endpoint. Previously any logged-in user could trigger a collaborator
      # re-sync of — and enumerate — repositories of other organizations.
      context "when the caller does not collaborate in the installation" do
        let(:outsider) { FactoryBot.create(:user, :github_connection) }

        it "refuses to refresh a cached repository and never calls GitHub" do
          allow(Collaborators).to receive(:refresh)

          result = described_class.targeted(outsider.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Grant access on GitHub first/)
          expect(Collaborators).not_to have_received(:refresh)
          expect(Repositories::Worker.jobs).to be_empty
        end

        it "refuses to re-sync the owner installation for an uncached repository" do
          result = described_class.targeted(outsider.id, "renderedtext/brand-new-repo")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Grant access on GitHub first/)
          expect(Repositories::Worker.jobs).to be_empty
        end

        it "gives outsiders no signal that distinguishes a real repository from a missing one" do
          real_repo = described_class.targeted(outsider.id, "renderedtext/guard")
          missing_repo = described_class.targeted(outsider.id, "ghost-owner/ghost-repo")

          expect(real_repo.state).to eq(:failed)
          expect(real_repo.state).to eq(missing_repo.state)
          expect(real_repo.message).to match(/Grant access on GitHub first/)
          expect(missing_repo.message).to match(/Grant access on GitHub first/)
        end
      end

      context "when the caller has no GitHub connection" do
        let(:user_without_github) { FactoryBot.create(:user) }

        it "is refused" do
          result = described_class.targeted(user_without_github.id, "renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Grant access on GitHub first/)
          expect(Repositories::Worker.jobs).to be_empty
        end
      end
    end

    context "when DISABLE_REPOSITORY_WEBHOOK_SYNC is set" do
      before do
        allow(App).to receive(:disable_repository_webhook_sync).and_return(true)
      end

      it "still enqueues the repository sync — manual refresh is not gated by the env flag" do
        user = FactoryBot.create(:user, :github_connection)
        installation = FactoryBot.create(:github_app_installation)
        GithubAppCollaborator.create!(
          :c_id => user.github_repo_host_account.github_uid,
          :c_name => "user",
          :r_name => "renderedtext/guard",
          :installation_id => installation.installation_id
        )

        result = described_class.full(user.id)

        expect(result.state).to eq(:started)
        expect(Repositories::Worker.jobs.map { |job| job["args"] })
          .to eq([[installation.installation_id]])
      end
    end
  end
end
