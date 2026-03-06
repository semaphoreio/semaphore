require "spec_helper"

module Semaphore::GithubApp
  RSpec.describe Collaborators do
    before do
      Semaphore::GithubApp::Credentials.instance_variable_set(:@private_key, nil)
      allow_any_instance_of(RepoHost::Github::Client).to receive(:rate_limit_remaining).and_return(10000)
    end

    describe ".refresh" do
      vcr_options = { :cassette_name => "GithubAppCollaborators/connection_working", :record => :new_episodes }
      context "for new installation", :vcr => vcr_options do
        it "adds collaborators" do
          FactoryBot.create(:github_app_installation, :installation_id => 13612966,
                                                      :repositories => ["renderedtext/guard"])

          expect(GithubAppCollaborator.count).to eq(0)

          described_class.refresh("renderedtext/guard")

          expect(GithubAppCollaborator.all.pluck(:c_name).sort).to eq(%w[markoa markoa2 radwo].sort)
        end
      end

      context "there is new collaborator", :vcr => vcr_options do
        it "adds collaborator" do
          FactoryBot.create(:github_app_installation, :installation_id => 13612966,
                                                      :repositories => ["renderedtext/guard"])

          GithubAppCollaborator.create(
            :r_name => "renderedtext/guard",
            :c_name => "markoa2",
            :c_id => 8652,
            :installation_id => 13612966
          )

          expect(GithubAppCollaborator.count).to eq(1)

          described_class.refresh("renderedtext/guard")

          expect(GithubAppCollaborator.all.pluck(:c_name).sort).to eq(%w[markoa markoa2 radwo].sort)
        end
      end

      context "one collaborator left the repository", :vcr => vcr_options do
        it "removes collaborator" do
          FactoryBot.create(:github_app_installation, :installation_id => 13612966,
                                                      :repositories => ["renderedtext/guard"])

          GithubAppCollaborator.create(
            :r_name => "renderedtext/guard",
            :c_name => "markoa",
            :c_id => 8651,
            :installation_id => 13612966
          )
          GithubAppCollaborator.create(
            :r_name => "renderedtext/guard",
            :c_name => "darkofabijan",
            :c_id => 20469,
            :installation_id => 13612966
          )
          GithubAppCollaborator.create(
            :r_name => "renderedtext/guard",
            :c_name => "radwo",
            :c_id => 184065,
            :installation_id => 13612966
          )

          expect(GithubAppCollaborator.count).to eq(3)

          described_class.refresh("renderedtext/guard")

          expect(GithubAppCollaborator.all.pluck(:c_name).sort).to eq(%w[markoa markoa2 radwo].sort)
        end
      end

      context "low API rate limits", :vcr => vcr_options do
        it "returns low rate limit" do
          FactoryBot.create(:github_app_installation, :installation_id => 13612966,
                                                      :repositories => ["renderedtext/guard"])

          GithubAppCollaborator.create(
            :r_name => "renderedtext/guard",
            :c_name => "markoa2",
            :c_id => 8652,
            :installation_id => 13612966
          )
          allow_any_instance_of(RepoHost::Github::Client).to receive(:rate_limit_remaining).and_return(100)

          result = described_class.refresh("renderedtext/guard")

          expect(result).to eq(:low_rate_limit)
        end
      end

      context "rate limit threshold" do
        let(:repository_slug) { "acme/repo" }
        let(:remaining_calls) { 100 }
        let(:client) { instance_double(RepoHost::Github::Client, :rate_limit_remaining => remaining_calls) }

        before do
          allow(described_class).to receive(:new_client).with(repository_slug, nil).and_return(client)
          allow(described_class).to receive(:fetch_collaborators).with(client, repository_slug).and_return([])
        end

        it "returns ok when remaining calls are above the configured threshold" do
          allow(App).to receive(:collaborators_api_rate_limit).and_return(50)

          result = described_class.refresh(repository_slug)

          expect(result).to eq(:ok)
        end

        it "returns low rate limit when remaining calls are below the configured threshold" do
          allow(App).to receive(:collaborators_api_rate_limit).and_return(101)

          result = described_class.refresh(repository_slug)

          expect(result).to eq(:low_rate_limit)
          expect(described_class).not_to have_received(:fetch_collaborators)
        end
      end
    end
  end
end
