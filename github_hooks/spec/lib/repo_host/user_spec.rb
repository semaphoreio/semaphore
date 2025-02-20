require "spec_helper"

RSpec.describe RepoHost::User do
  let(:repo_host_account) do
    FactoryBot.build(:repo_host_account,
                     :token => "4804c46c4f7536c2a83be0b3d53345d1ff67a041")
  end
  let(:login) { double }
  let(:repo_host) { double }

  describe ".repositories" do
    before do
      allow(RepoHost::Factory).to receive(:create_repo_host) { repo_host }
    end

    it "calls repositories for repo host" do
      expect(repo_host).to receive(:repositories)

      RepoHost::User.repositories(repo_host_account)
    end
  end

  describe ".group_repositories" do
    before do
      allow(RepoHost::Factory).to receive(:create_repo_host) { repo_host }
    end

    it "calls group_repositories for repo host" do
      expect(repo_host).to receive(:group_repositories)

      RepoHost::User.group_repositories(repo_host_account)
    end
  end

  describe ".organizations" do
    before do
      allow(RepoHost::Factory).to receive(:create_repo_host) { repo_host }
    end

    it "calls organization for repo host" do
      expect(repo_host).to receive(:organizations)

      RepoHost::User.organizations(repo_host_account)
    end
  end

  describe ".email" do

    before do
      allow(RepoHost::User).to receive(:emails).and_return(RepoHost::Github::Responses::User.emails)
      @emails = RepoHost::User.emails(repo_host_account)
    end

    it "returns a Array" do
      expect(@emails).to be_instance_of(Array)
    end

    it "contains emails" do
      expect(@emails).to include("octocat@github.com")
    end

  end

  describe ".user" do
    before do
      allow(RepoHost::Factory).to receive(:create_repo_host) { repo_host }
    end

    it "calls user for repo host" do
      expect(repo_host).to receive(:user).with(login)

      RepoHost::User.user(repo_host_account, login)
    end
  end
end
