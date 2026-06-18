require "spec_helper"

module Semaphore::GithubApp
  RSpec.describe RepositoryRefresh, :aggregate_failures do
    before do
      Sidekiq::Worker.clear_all
      allow_any_instance_of(Repositories::Worker).to receive(:unique_lock_exists?).and_return(false)
    end

    describe ".full" do
      context "when there are no installations" do
        it "fails with an actionable message" do
          result = described_class.full

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/Install the GitHub App/)
        end
      end

      context "when all installations are suspended" do
        before do
          FactoryBot.create(:github_app_installation, :suspended_at => Time.zone.now)
        end

        it "fails with an actionable message" do
          result = described_class.full

          expect(result.state).to eq(:failed)
          expect(Repositories::Worker.jobs).to be_empty
        end
      end

      context "when all installations are already being synced" do
        before do
          FactoryBot.create(:github_app_installation)
          allow_any_instance_of(Repositories::Worker).to receive(:unique_lock_exists?).and_return(true)
        end

        it "reports the sync as already running without enqueueing" do
          result = described_class.full

          expect(result.state).to eq(:already_running)
          expect(Repositories::Worker.jobs).to be_empty
          expect(Collaborators::Worker.jobs).to be_empty
        end
      end

      context "with free installations" do
        let!(:installation) { FactoryBot.create(:github_app_installation) }

        it "enqueues a repository list sync per installation" do
          result = described_class.full

          expect(result.state).to eq(:started)
          expect(Repositories::Worker.jobs.map { |job| job["args"] })
            .to eq([[installation.installation_id]])
        end

        it "enqueues a collaborator sync for every cached repository" do
          described_class.full

          enqueued = Collaborators::Worker.jobs.map { |job| job["args"] }
          expect(enqueued).to contain_exactly(["renderedtext/guard", 0], ["semaphoreio/semaphore", 0])
        end

        it "skips locked installations but refreshes free ones" do
          locked = FactoryBot.create(
            :github_app_installation,
            :installation_id => 555,
            :repositories => ["acme/anvil"]
          )

          allow_any_instance_of(Repositories::Worker).to receive(:unique_lock_exists?) do |_worker, lock_args|
            lock_args == [locked.installation_id]
          end

          result = described_class.full

          expect(result.state).to eq(:started)
          expect(Repositories::Worker.jobs.map { |job| job["args"] })
            .to eq([[installation.installation_id]])
        end
      end
    end

    describe ".targeted" do
      let!(:installation) { FactoryBot.create(:github_app_installation) }

      it "rejects input that is not an owner/repository slug" do
        result = described_class.targeted("not a slug")

        expect(result.state).to eq(:failed)
        expect(result.message).to match(%r{owner/repository})
      end

      context "when the repository is cached" do
        it "refreshes collaborators with the stored slug and remote id" do
          allow(Collaborators).to receive(:refresh).and_return(:ok)

          result = described_class.targeted("RenderedText/Guard")

          expect(Collaborators).to have_received(:refresh).with("renderedtext/guard", 0)
          expect(result.state).to eq(:done)
          expect(result.message).to include("renderedtext/guard")
        end

        it "maps :no_token to a failure about app access" do
          allow(Collaborators).to receive(:refresh).and_return(:no_token)

          result = described_class.targeted("renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/no access/)
        end

        it "maps :no_repository to a failure about the repository" do
          allow(Collaborators).to receive(:refresh).and_return(:no_repository)

          result = described_class.targeted("renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/not found on GitHub/)
        end

        it "maps :low_rate_limit to a retry-later failure" do
          allow(Collaborators).to receive(:refresh).and_return(:low_rate_limit)

          result = described_class.targeted("renderedtext/guard")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/rate limit/)
        end
      end

      context "when the repository is not cached" do
        it "re-syncs the owner's installation repository list" do
          result = described_class.targeted("renderedtext/brand-new-repo")

          expect(result.state).to eq(:started)
          expect(Repositories::Worker.jobs.map { |job| job["args"] })
            .to eq([[installation.installation_id]])
        end

        it "reports an already running sync for the owner's installation" do
          allow_any_instance_of(Repositories::Worker).to receive(:unique_lock_exists?).and_return(true)

          result = described_class.targeted("renderedtext/brand-new-repo")

          expect(result.state).to eq(:already_running)
          expect(Repositories::Worker.jobs).to be_empty
        end

        it "fails when no installation covers the owner" do
          result = described_class.targeted("unknown-owner/repo")

          expect(result.state).to eq(:failed)
          expect(result.message).to match(/no access/)
        end
      end
    end
  end
end
