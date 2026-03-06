require "spec_helper"

module Semaphore::GithubApp
  RSpec.describe Repositories do
    describe ".refresh" do
      let(:installation_id) { 13609976 }
      let(:token) { "token" }
      let(:client) { instance_double(RepoHost::Github::Client, :rate_limit_remaining => 10_000) }

      let(:current_repositories) do
        # 0..1999
        (0...2000).map do |i|
          { "id" => 0, "slug" => "acme/repo-#{i}" }
        end
      end

      let(:remote_repositories) do
        # 200..2199, so:
        # - 200 removed (0..199)
        # - 200 added (2000..2199)
        # - 1800 kept with id updates (200..1999)
        (200...2200).map do |i|
          { "id" => 100_000 + i, "slug" => "acme/repo-#{i}" }
        end
      end

      before do
        allow(Semaphore::GithubApp::Token).to receive(:installation_token).with(installation_id).and_return([token, 1.hour.from_now.iso8601])
        allow(RepoHost::Github::Client).to receive(:new).with(token).and_return(client)

        allow_any_instance_of(described_class).to receive(:current_repositories).and_return(current_repositories)
        allow_any_instance_of(described_class).to receive(:remote_repositories).and_return(remote_repositories)

        allow(Semaphore::GithubApp::Hook).to receive(:add_repositories)
        allow(Semaphore::GithubApp::Hook).to receive(:remove_repositories)
      end

      it "handles refresh with 2k repositories" do
        result = described_class.refresh(installation_id)

        expect(result).to eq(:ok)
        expect(Semaphore::GithubApp::Hook).to have_received(:add_repositories).with(installation_id, satisfy { |repositories| repositories.size == 200 })
        expect(Semaphore::GithubApp::Hook).to have_received(:remove_repositories).with(installation_id, satisfy { |repositories| repositories.size == 200 })
      end

      context "when a repository slug differs only by letter case" do
        let(:current_repositories) { [{ "id" => 42, "slug" => "Acme/Repo" }] }
        let(:remote_repositories) { [{ "id" => 42, "slug" => "acme/repo" }] }

        it "does not schedule add or remove for the same canonical slug" do
          result = described_class.refresh(installation_id)

          expect(result).to eq(:ok)
          expect(Semaphore::GithubApp::Hook).to have_received(:add_repositories).with(installation_id, [])
          expect(Semaphore::GithubApp::Hook).to have_received(:remove_repositories).with(installation_id, [])
        end
      end

      context "rate limit threshold" do
        before do
          allow(App).to receive(:collaborators_api_rate_limit).and_return(50)
        end

        it "returns ok when remaining calls are above the configured threshold" do
          allow(client).to receive(:rate_limit_remaining).and_return(100)

          result = described_class.refresh(installation_id)

          expect(result).to eq(:ok)
        end

        it "returns low rate limit when remaining calls are below the configured threshold" do
          allow(App).to receive(:collaborators_api_rate_limit).and_return(101)
          allow(client).to receive(:rate_limit_remaining).and_return(49)

          result = described_class.refresh(installation_id)

          expect(result).to eq(:low_rate_limit)
          expect(Semaphore::GithubApp::Hook).not_to have_received(:add_repositories)
          expect(Semaphore::GithubApp::Hook).not_to have_received(:remove_repositories)
        end
      end
    end
  end
end
