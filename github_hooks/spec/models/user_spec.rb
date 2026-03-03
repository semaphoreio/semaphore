require "spec_helper"

RSpec.describe User, :type => :model do
  it { is_expected.to have_many(:repo_host_accounts).dependent(:destroy) }

  describe "#service_account?" do
    context "when creation_source is 'service_account'" do
      let(:user) { FactoryBot.build(:user, creation_source: "service_account") }

      it "returns true" do
        expect(user.service_account?).to be_truthy
      end
    end

    context "when creation_source is not 'service_account'" do
      let(:user) { FactoryBot.build(:user, creation_source: "github") }

      it "returns false" do
        expect(user.service_account?).to be_falsey
      end
    end

    context "when creation_source is nil" do
      let(:user) { FactoryBot.build(:user, creation_source: nil) }

      it "returns false" do
        expect(user.service_account?).to be_falsey
      end
    end
  end

  describe "#github_repo_host_account" do
    context "when user is a regular user with github connection" do
      let(:user) { FactoryBot.create(:user, :github_connection) }

      it "returns the actual RepoHostAccount" do
        account = user.github_repo_host_account
        expect(account).to be_a(RepoHostAccount)
        expect(account.repo_host).to eq(::Repository::GITHUB_PROVIDER)
      end
    end

    context "when user is a regular user without github connection" do
      let(:user) { FactoryBot.create(:user, name: "Regular User", email: "regular@example.com") }

      it "returns a synthetic account object" do
        account = user.github_repo_host_account
        expect(account).to be_a(User::SyntheticRepoHostAccount)
      end

      it "provides expected name from user.name" do
        account = user.github_repo_host_account
        expect(account.name).to eq("Regular User")
      end

      it "provides empty string fallback when name is nil" do
        user.update!(name: nil)
        account = user.github_repo_host_account
        expect(account.name).to eq("")
      end

      it "provides a deterministic github_uid based on user id with 'user' prefix" do
        account = user.github_repo_host_account
        expected_uid = "user_#{user.id}".hash.abs.to_s
        expect(account.github_uid).to eq(expected_uid)
      end

      it "provides github_uid as login" do
        account = user.github_repo_host_account
        expect(account.login).to eq(account.github_uid)
      end

      it "provides correct repo_host" do
        account = user.github_repo_host_account
        expect(account.repo_host).to eq(::Repository::GITHUB_PROVIDER)
      end

      it "caches the synthetic account object" do
        account1 = user.github_repo_host_account
        account2 = user.github_repo_host_account
        expect(account1).to be(account2)
      end
    end

    context "when user is a service account" do
      let(:user) { FactoryBot.create(:user, creation_source: "service_account", name: "Test Service Account") }

      it "returns a synthetic account object" do
        account = user.github_repo_host_account
        expect(account).to be_a(User::SyntheticRepoHostAccount)
      end

      it "provides expected name from user.name" do
        account = user.github_repo_host_account
        expect(account.name).to eq("Test Service Account")
      end

      it "provides 'Service Account' fallback when name is nil" do
        user.update!(name: nil)
        account = user.github_repo_host_account
        expect(account.name).to eq("Service Account")
      end

      it "provides a deterministic github_uid based on user id" do
        account = user.github_repo_host_account
        expected_uid = "service_account_#{user.id}".hash.abs.to_s
        expect(account.github_uid).to eq(expected_uid)
      end

      it "provides 'service-account' login" do
        account = user.github_repo_host_account
        expect(account.login).to eq("service-account")
      end

      it "provides correct repo_host" do
        account = user.github_repo_host_account
        expect(account.repo_host).to eq(::Repository::GITHUB_PROVIDER)
      end

      it "caches the synthetic account object" do
        account1 = user.github_repo_host_account
        account2 = user.github_repo_host_account
        expect(account1).to be(account2)
      end
    end
  end
end
