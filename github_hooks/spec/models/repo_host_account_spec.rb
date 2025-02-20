require "spec_helper"

RSpec.describe RepoHostAccount, :type => :model do
  it { is_expected.to belong_to(:user) }

  describe "scopes" do
    before do
      @github_account = FactoryBot.create(:github_account_marvin)
      @bitbucket_account = FactoryBot.create(:bitbucket_account_marvin)
    end

    describe ".github" do
      it "returns GitHub accounts" do
        expect(RepoHostAccount.github).to match([@github_account])
      end
    end

    describe ".bitbucket" do
      it "returns Bitbucket accounts" do
        expect(RepoHostAccount.bitbucket).to match([@bitbucket_account])
      end
    end
  end
end
