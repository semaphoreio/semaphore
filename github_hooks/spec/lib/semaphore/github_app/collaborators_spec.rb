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
    end
  end
end
