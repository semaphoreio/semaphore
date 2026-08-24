require "spec_helper"

module Semaphore::GithubApp
  class Repositories
    RSpec.describe RemoteIdBackfill do
      describe ".refresh_installation" do
        let(:installation_id) { 13609976 }
        let(:token) { "token" }
        let(:client) { instance_double(RepoHost::Github::Client, :rate_limit_remaining => 10_000) }

        before do
          FactoryBot.create(
            :github_app_installation,
            :installation_id => installation_id,
            :repositories => [
              { "id" => 0, "slug" => "acme/repo-1" },
              { "id" => 0, "slug" => "acme/repo-2" },
              { "id" => 4455, "slug" => "acme/repo-3" }
            ]
          )

          allow(Semaphore::GithubApp::Token).to receive(:installation_token).with(installation_id).and_return([token, 1.hour.from_now.iso8601])
          allow(RepoHost::Github::Client).to receive(:new).with(token).and_return(client)
          allow_any_instance_of(described_class).to receive(:remote_repositories_from_github).and_return(
            [
              { "id" => 111, "slug" => "acme/repo-1" },
              { "id" => 222, "slug" => "Acme/Repo-2" },
              { "id" => 333, "slug" => "acme/repo-does-not-exist" }
            ]
          )
        end

        it "updates only missing remote_id values in github app installation repositories" do
          result = described_class.refresh_installation(installation_id)

          repositories = GithubAppInstallationRepository.where(:installation_id => installation_id).order(:slug)
          expect(result[:status]).to eq(:ok)
          expect(result[:updated_count]).to eq(2)
          expect(repositories.pluck(:slug, :remote_id)).to eq(
            [
              ["acme/repo-1", 111],
              ["acme/repo-2", 222],
              ["acme/repo-3", 4455]
            ]
          )
        end
      end

      describe ".refresh_next_installation" do
        let(:token) { "token" }
        let(:client) { instance_double(RepoHost::Github::Client, :rate_limit_remaining => 10_000) }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => 1001, :repositories => [{ "id" => 0, "slug" => "acme/repo-1" }])
          FactoryBot.create(:github_app_installation, :installation_id => 1002, :repositories => [{ "id" => 0, "slug" => "acme/repo-2" }])

          allow(Semaphore::GithubApp::Token).to receive(:installation_token).and_return([token, 1.hour.from_now.iso8601])
          allow(RepoHost::Github::Client).to receive(:new).with(token).and_return(client)
          allow_any_instance_of(described_class).to receive(:remote_repositories_from_github).and_return(
            [
              { "id" => 111, "slug" => "acme/repo-1" },
              { "id" => 222, "slug" => "acme/repo-2" }
            ]
          )
        end

        it "processes a single installation per run" do
          result = described_class.refresh_next_installation

          expect(result[:status]).to eq(:ok)
          expect(result[:installation_id]).to eq(1001)
          expect(result[:remaining_installations]).to be(true)

          first_remote_id = GithubAppInstallationRepository.find_by!(:installation_id => 1001, :slug => "acme/repo-1").remote_id
          second_remote_id = GithubAppInstallationRepository.find_by!(:installation_id => 1002, :slug => "acme/repo-2").remote_id

          expect(first_remote_id).to eq(111)
          expect(second_remote_id).to eq(0)
        end
      end

      describe "#remote_repositories_from_github" do
        let(:installation_id) { 13609976 }
        let(:token) { "token" }
        let(:backfill) { described_class.new }

        before do
          backfill.instance_variable_set(:@current_installation_id, installation_id)
          allow(Semaphore::GithubApp::Token).to receive(:installation_token).with(installation_id).and_return([token, 1.hour.from_now.iso8601])
        end

        it "raises when repositories is missing" do
          allow(Excon).to receive(:get).and_return(
            instance_double(
              Excon::Response,
              :data => { :body => JSON.generate({ "total_count" => 1 }) },
              :headers => {}
            )
          )

          expect do
            backfill.send(:remote_repositories_from_github)
          end.to raise_error(Repositories::InvalidRepositoryListResponseError, /Missing repositories/)
        end

        it "raises when total_count is missing" do
          allow(Excon).to receive(:get).and_return(
            instance_double(
              Excon::Response,
              :data => { :body => JSON.generate({ "repositories" => [{ "id" => 1, "full_name" => "acme/repo-1" }] }) },
              :headers => {}
            )
          )

          expect do
            backfill.send(:remote_repositories_from_github)
          end.to raise_error(Repositories::InvalidRepositoryListResponseError, /installation_id=13609976/)
        end

        it "raises when total_count is not an integer" do
          allow(Excon).to receive(:get).and_return(
            instance_double(
              Excon::Response,
              :data => { :body => JSON.generate({ "total_count" => "bogus", "repositories" => [{ "id" => 1, "full_name" => "acme/repo-1" }] }) },
              :headers => {}
            )
          )

          expect do
            backfill.send(:remote_repositories_from_github)
          end.to raise_error(Repositories::InvalidRepositoryListResponseError, /installation_id=13609976/)
        end

        it "raises when total_count is negative" do
          allow(Excon).to receive(:get).and_return(
            instance_double(
              Excon::Response,
              :data => { :body => JSON.generate({ "total_count" => -1, "repositories" => [{ "id" => 1, "full_name" => "acme/repo-1" }] }) },
              :headers => {}
            )
          )

          expect do
            backfill.send(:remote_repositories_from_github)
          end.to raise_error(Repositories::InvalidRepositoryListResponseError, /installation_id=13609976/)
        end

        it "raises when pagination stops before the advertised total_count is fetched" do
          page_1_repos = (1..100).map { |i| { "id" => i, "full_name" => "acme/repo-#{i}" } }
          page_2_repos = (101..200).map { |i| { "id" => i, "full_name" => "acme/repo-#{i}" } }

          allow(Excon).to receive(:get).and_return(
            instance_double(
              Excon::Response,
              :data => { :body => JSON.generate({ "total_count" => 399, "repositories" => page_1_repos }) },
              :headers => { "Link" => '<https://api.github.com/installation/repositories?per_page=100&page=2>; rel="next"' }
            ),
            instance_double(
              Excon::Response,
              :data => { :body => JSON.generate({ "total_count" => 399, "repositories" => page_2_repos }) },
              :headers => {}
            )
          )

          expect do
            backfill.send(:remote_repositories_from_github)
          end.to raise_error(Repositories::IncompleteRepositoryListError, /Fetched 200 repositories, expected 399/)
        end
      end

      describe "fair scheduling for unresolved installations" do
        it "deprioritizes installation when token is missing" do
          installation = FactoryBot.create(
            :github_app_installation,
            :installation_id => 9011,
            :repositories => [{ "id" => 0, "slug" => "acme/repo-1" }]
          )
          repository = installation.installation_repositories.first
          previous_updated_at = 2.hours.ago
          repository.update_column(:updated_at, previous_updated_at) # rubocop:disable Rails/SkipsModelValidations

          allow(Semaphore::GithubApp::Token).to receive(:installation_token).with(9011).and_return([nil, nil])

          result = described_class.refresh_installation(9011)

          expect(result[:status]).to eq(:no_token)
          expect(repository.reload.updated_at).to be > previous_updated_at
        end

        it "deprioritizes orphaned installation rows when installation does not exist" do
          orphaned_repository = GithubAppInstallationRepository.create!(
            :installation_id => 9022,
            :remote_id => 0,
            :slug => "acme/repo-2"
          )
          previous_updated_at = 2.hours.ago
          orphaned_repository.update_column(:updated_at, previous_updated_at) # rubocop:disable Rails/SkipsModelValidations
          client = instance_double(RepoHost::Github::Client, :rate_limit_remaining => 10_000)

          allow(Semaphore::GithubApp::Token).to receive(:installation_token).with(9022).and_return(["token", 1.hour.from_now.iso8601])
          allow(RepoHost::Github::Client).to receive(:new).with("token").and_return(client)

          result = described_class.refresh_installation(9022)

          expect(result[:status]).to eq(:no_installation)
          expect(orphaned_repository.reload.updated_at).to be > previous_updated_at
        end
      end

      # The remote_id backfill has its OWN rate-limit threshold
      # (App.remote_id_backfill_rate_limit / REMOTE_ID_BACKFILL_RATE_LIMIT), decoupled from the
      # shared collaborators_api_rate_limit that operators set very high to protect quota from the
      # heavy collaborators refresh (repos x collaborators). Decoupling lets the cheap backfill run
      # at a lower threshold without touching the collaborators protection.
      describe "remote_id backfill rate-limit threshold (decoupled config)" do
        let(:installation_id) { 1001 }
        let(:token) { "token" }

        before do
          FactoryBot.create(
            :github_app_installation,
            :installation_id => installation_id,
            :repositories => [{ "id" => 0, "slug" => "acme/repo-1" }]
          )
          allow(Semaphore::GithubApp::Token).to receive(:installation_token).and_return([token, 1.hour.from_now.iso8601])
        end

        it "defers when remaining quota is below App.remote_id_backfill_rate_limit" do
          allow(App).to receive(:remote_id_backfill_rate_limit).and_return(5000)
          client = instance_double(RepoHost::Github::Client, :rate_limit_remaining => 4000)
          allow(RepoHost::Github::Client).to receive(:new).with(token).and_return(client)

          result = described_class.refresh_installation(installation_id)

          expect(result[:status]).to eq(:low_rate_limit)
          expect(
            GithubAppInstallationRepository.where(:installation_id => installation_id).pluck(:remote_id)
          ).to all(eq(0))
        end

        it "proceeds when remaining quota is at/above App.remote_id_backfill_rate_limit" do
          allow(App).to receive(:remote_id_backfill_rate_limit).and_return(5000)
          client = instance_double(RepoHost::Github::Client, :rate_limit_remaining => 6000)
          allow(RepoHost::Github::Client).to receive(:new).with(token).and_return(client)
          allow_any_instance_of(described_class).to receive(:remote_repositories_from_github).and_return(
            [{ "id" => 111, "slug" => "acme/repo-1" }]
          )

          result = described_class.refresh_installation(installation_id)

          expect(result[:status]).to eq(:ok)
          expect(
            GithubAppInstallationRepository.find_by(:installation_id => installation_id, :slug => "acme/repo-1").remote_id
          ).to eq(111)
        end

        it "is gated only by its own threshold, NOT by collaborators_api_rate_limit" do
          # A very high collaborators threshold must not throttle the backfill: with the backfill's
          # own threshold at 1000 and 2000 remaining, it proceeds even though 2000 < collaborators (1M).
          allow(App).to receive_messages(:collaborators_api_rate_limit => 1_000_000, :remote_id_backfill_rate_limit => 1000)
          client = instance_double(RepoHost::Github::Client, :rate_limit_remaining => 2000)
          allow(RepoHost::Github::Client).to receive(:new).with(token).and_return(client)
          allow_any_instance_of(described_class).to receive(:remote_repositories_from_github).and_return(
            [{ "id" => 111, "slug" => "acme/repo-1" }]
          )

          result = described_class.refresh_installation(installation_id)

          expect(result[:status]).to eq(:ok)
        end
      end

      describe "App.remote_id_backfill_rate_limit configuration" do
        it "falls back to collaborators_api_rate_limit when REMOTE_ID_BACKFILL_RATE_LIMIT is unset" do
          # No dedicated env var in the test environment => the decoupled knob defaults to the
          # collaborators threshold, so behavior is unchanged unless explicitly overridden.
          expect(App.remote_id_backfill_rate_limit).to eq(App.collaborators_api_rate_limit)
        end
      end
    end
  end
end
