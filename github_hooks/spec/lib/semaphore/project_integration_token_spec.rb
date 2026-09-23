require "spec_helper"

RSpec.describe Semaphore::ProjectIntegrationToken do
  describe "#github_oauth_token" do
    before do
      @user = FactoryBot.create(:user)
      @repo = FactoryBot.create(:repo_host_account, :user => @user)
    end

    it "returns github oauth token of an user" do
      expect(described_class.new.github_oauth_token(@user)).to eq([@repo.token, nil])
    end
  end

  describe "#bitbucket_oauth_token" do
    before do
      @user = FactoryBot.create(:user)
      @repo = FactoryBot.create(:bitbucket_account, :user => @user)
    end

    it "returns the stored bitbucket credential of a user" do
      expect(described_class.new.bitbucket_oauth_token(@user))
        .to eq([@repo.token, @repo.token_expires_at])
    end

    # Bitbucket refresh tokens are single-use and rotating; only guard
    # refreshes them.
    it "never talks to bitbucket" do
      expect(Excon).not_to receive(:post)
      expect(Excon).not_to receive(:get)

      described_class.new.bitbucket_oauth_token(@user)
    end

    context "when the user has no bitbucket connection" do
      # get_token feeds this into a proto3 string field, which rejects nil.
      it "returns an empty credential instead of raising" do
        expect(described_class.new.bitbucket_oauth_token(FactoryBot.create(:user)))
          .to eq(["", nil])
      end
    end
  end

  describe "#github_app_token" do
    it "returns github app token for an repository" do
      allow(Semaphore::GithubApp::Token).to receive(:repository_token).with(
        :repository_slug => "renderedtext/guard",
        :repository_remote_id => nil
      ).and_return("foo")

      expect(described_class.new.github_app_token(:repository_slug => "renderedtext/guard")).to eq("foo")
    end
  end

  describe "#project_token" do
    context "project based on github_oauth_token integration" do
      before do
        user = FactoryBot.create(:user)
        @repo = FactoryBot.create(:repo_host_account, :user => user)

        @project = FactoryBot.create(:project, :creator => user)
        @project.repository.update(:integration_type => "github_oauth_token")
      end

      it "returns github_app token" do
        expect(described_class.new.project_token(@project)).to eq([@repo.token, nil])
      end

    end

    context "project based on github_app integration" do
      before do
        @project = FactoryBot.create(:project)
        @project.repository.update(:integration_type => "github_app")
      end

      it "returns github_app token" do
        allow(Semaphore::GithubApp::Token).to receive(:repository_token)
          .with(
            :repository_slug => @project.repo_owner_and_name,
            :repository_remote_id => @project.repository.remote_id
          ).and_return("foo")

        expect(described_class.new.project_token(@project)).to eq("foo")
      end
    end
  end
end
