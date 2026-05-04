require "spec_helper"

module Semaphore::GithubApp
  RSpec.describe Repositories do
    describe "#get_remote_repositories" do
      let(:installation_id) { 13609976 }
      let(:token) { "token" }
      let(:repositories) { described_class.new(installation_id) }

      before do
        allow(Semaphore::GithubApp::Token).to receive(:installation_token).with(installation_id).and_return([token, 1.hour.from_now.iso8601])
      end

      it "follows the Link header and returns the full list" do
        page_1_repos = (1..100).map { |i| { "id" => i, "full_name" => "acme/repo-#{i}" } }
        page_2_repos = (101..200).map { |i| { "id" => i, "full_name" => "acme/repo-#{i}" } }
        page_3_repos = (201..300).map { |i| { "id" => i, "full_name" => "acme/repo-#{i}" } }
        page_4_repos = (301..399).map { |i| { "id" => i, "full_name" => "acme/repo-#{i}" } }

        allow(Excon).to receive(:get).and_return(
          instance_double(
            Excon::Response,
            :data => { :body => JSON.generate({ "total_count" => 399, "repositories" => page_1_repos }) },
            :headers => { "Link" => '<https://api.github.com/installation/repositories?per_page=100&page=2>; rel="next"' }
          ),
          instance_double(
            Excon::Response,
            :data => { :body => JSON.generate({ "total_count" => 399, "repositories" => page_2_repos }) },
            :headers => { "Link" => '<https://api.github.com/installation/repositories?per_page=100&page=3>; rel="next"' }
          ),
          instance_double(
            Excon::Response,
            :data => { :body => JSON.generate({ "total_count" => 399, "repositories" => page_3_repos }) },
            :headers => { "Link" => '<https://api.github.com/installation/repositories?per_page=100&page=4>; rel="next"' }
          ),
          instance_double(
            Excon::Response,
            :data => { :body => JSON.generate({ "total_count" => 399, "repositories" => page_4_repos }) },
            :headers => {}
          )
        )

        result = repositories.send(:get_remote_repositories)

        expect(result.size).to eq(399)
        expect(result.first).to eq({ "id" => 1, "slug" => "acme/repo-1" })
        expect(result.last).to eq({ "id" => 399, "slug" => "acme/repo-399" })
        expect(Excon).to have_received(:get).with(
          "https://api.github.com/installation/repositories?per_page=100&page=1",
          hash_including(
            :headers => hash_including(
              "Authorization" => "token #{token}",
              "Accept" => "application/vnd.github.v3+json"
            ),
            :idempotent => true,
            :retry_limit => described_class::EXCON_RETRY_LIMIT,
            :expects => [200]
          )
        )
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
          repositories.send(:get_remote_repositories)
        end.to raise_error(described_class::IncompleteRepositoryListError, /Fetched 200 repositories, expected 399/)
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
          repositories.send(:get_remote_repositories)
        end.to raise_error(described_class::InvalidRepositoryListResponseError, /installation_id=13609976/)
      end

      it "raises when total_count is not an integer" do
        allow(Excon).to receive(:get).and_return(
          instance_double(
            Excon::Response,
            :data => { :body => JSON.generate({ "total_count" => "not-a-number", "repositories" => [{ "id" => 1, "full_name" => "acme/repo-1" }] }) },
            :headers => {}
          )
        )

        expect do
          repositories.send(:get_remote_repositories)
        end.to raise_error(described_class::InvalidRepositoryListResponseError, /installation_id=13609976/)
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
          repositories.send(:get_remote_repositories)
        end.to raise_error(described_class::InvalidRepositoryListResponseError, /installation_id=13609976/)
      end
    end

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
    end
  end
end
