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

  describe "#github_app_token" do
    it "returns github app token for an repository" do
      allow(Semaphore::GithubApp::Token).to receive(:repository_token).with("renderedtext/guard").and_return("foo")

      expect(described_class.new.github_app_token("renderedtext/guard")).to eq("foo")
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
        allow(Semaphore::GithubApp::Token).to receive(:repository_token).with(@project.repo_owner_and_name).and_return("foo")

        expect(described_class.new.project_token(@project)).to eq("foo")
      end
    end
  end
end
