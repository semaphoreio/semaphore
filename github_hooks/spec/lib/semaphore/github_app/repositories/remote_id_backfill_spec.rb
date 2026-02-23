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
    end
  end
end
