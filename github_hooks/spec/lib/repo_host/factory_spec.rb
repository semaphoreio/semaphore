require "spec_helper"

module RepoHost
  RSpec.describe Factory do
    describe "#create_repo_host" do
      context "when repo host is from GitHub" do
        let(:repo_host_account) do
          FactoryBot.create(:repo_host_account,
                            :repo_host => ::Repository::GITHUB_PROVIDER)
        end

        it "creates github client" do
          repo_host = Factory.create_repo_host(repo_host_account)

          expect(repo_host.class).to eq(RepoHost::Github::Client)
        end
      end
    end
  end
end
