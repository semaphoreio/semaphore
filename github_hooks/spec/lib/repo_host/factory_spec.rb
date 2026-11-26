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

    describe ".create_from_project" do
      let(:project) { instance_double(Project) }

      before do
        allow(::Semaphore::ProjectIntegrationToken).to receive(:new).and_return(instance_double(::Semaphore::ProjectIntegrationToken, :project_token => ["token", nil]))
      end

      it "passes the request timeout to the client" do
        allow(RepoHost::Github::Client).to receive(:new).and_call_original

        Factory.create_from_project(project, :request_timeout => 10)

        expect(RepoHost::Github::Client).to have_received(:new).with("token", :request_timeout => 10)
      end

      it "creates a client without a request timeout by default" do
        allow(RepoHost::Github::Client).to receive(:new).and_call_original

        Factory.create_from_project(project)

        expect(RepoHost::Github::Client).to have_received(:new).with("token", :request_timeout => nil)
      end
    end
  end
end
