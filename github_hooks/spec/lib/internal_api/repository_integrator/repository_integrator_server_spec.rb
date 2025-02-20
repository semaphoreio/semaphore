require "spec_helper"

RSpec.describe InternalApi::RepositoryIntegrator::RepositoryIntegratorServer do
  let(:server) { described_class.new }
  let(:call) { double }
  let(:user_id) { "uf39e29c-fbf6-4333-baa7-3606ab3e4827" }
  let(:repository_slug) { "renderedtext/guard" }
  let(:token) { "token" }
  let(:expires_at) { Time.zone.now }
  let(:non_existing_id) { "4898889a-9799-4e2e-8d60-6a8669e232aa" }

  before do
    allow(call).to receive(:metadata).and_return({})
  end

  describe "#get_file" do
    vcr_bad_credentials = { :cassette_name => "GitHub/GitHub_Contents/_get/bad_credentials", :record => :new_episodes }
    vcr_good_credentials = { :cassette_name => "GitHub/GitHub_Contents/_get/good_credentials",
                             :record => :new_episodes }

    context "fetching file for non existing project" do
      before do
        @req = InternalApi::RepositoryIntegrator::GetFileRequest.new(
          :project_id => non_existing_id,
          :path => "README.md",
          :ref => "30162c55162a184131b5d5c56f2eed78493e5c71"
        )
      end

      it "raise an exception" do
        expect do
          server.get_file(@req, call)
        end.to raise_exception(GRPC::NotFound)
      end
    end

    context "fetching file with bad credentials", :vcr => vcr_bad_credentials do
      before do
        user = FactoryBot.create(:user)
        user.repo_host_accounts << FactoryBot.create(:repo_host_account)
        repository = FactoryBot.create(:repository, :integration_type => "github_oauth_token")
        project = FactoryBot.create(:project, :creator => user, :repository => repository)
        repository.update(:owner => "renderedtext", :name => "plakatt")

        @req = InternalApi::RepositoryIntegrator::GetFileRequest.new(
          :project_id => project.id,
          :path => "README.md",
          :ref => "30162c55162a184131b5d5c56f2eed78493e5c71"
        )
      end

      it "raise an exception" do
        expect do
          server.get_file(@req, call)
        end.to raise_exception(GRPC::NotFound, "5:Bad credentials")
      end
    end

    context "fetching file with good credentials", :vcr => vcr_good_credentials do
      before do
        user = FactoryBot.create(:user)
        user.repo_host_accounts << FactoryBot.create(:repo_host_account)
        repository = FactoryBot.create(:repository, :integration_type => "github_oauth_token")
        project = FactoryBot.create(:project, :creator => user, :repository => repository)
        repository.update(:owner => "semaphoreci", :name => "docs")

        @req = InternalApi::RepositoryIntegrator::GetFileRequest.new(
          :project_id => project.id,
          :path => "README.md",
          :ref => "30162c55162a184131b5d5c56f2eed78493e5c71"
        )
      end

      it "returns file content" do
        response = server.get_file(@req, call)

        expect(response.content).to eq("WyFbQnVpbGQgU3RhdHVzXShodHRwczovL3NlbWFwaG9yZS5zZW1hcGhvcmVjaS5jb20vYmFkZ2VzL2RvY3Muc3ZnKV0oaHR0cHM6Ly9zZW1hcGhvcmUuc2VtYXBob3JlY2kuY29tL3Byb2plY3RzL2RvY3MpCgojIFNlbWFwaG9yZSAyLjAgRG9jdW1lbnRhdGlvbgoKVGhpcyBpcyB0aGUgc291cmNlIGNvbnRlbnQgb2YgW1NlbWFwaG9yZSAyLjAgZG9jdW1lbnRhdGlvbl1bZG9jcy13ZWJzaXRlXSwgYQp3ZWJzaXRlIGNvbnRpbnVvdXNseSBkZXBsb3llZCBmcm9tIE1hcmtkb3duIGZpbGVzIGluIHRoaXMgcmVwb3NpdG9yeS4KClBlb3BsZSBmcm9tIFNlbWFwaG9yZSB0ZWFtIGFyZSBtYWluIGNvbnRyaWJ1dG9ycyBvZiBjb250ZW50LCBidXQgd2UgYWxzbyB3ZWxjb21lCmFsbCBjb250cmlidXRpb25zIGZyb20gcHJvZHVjdCB1c2Vycy4gIElmIHlvdSBmaW5kIGFueSBlcnJvcnMgaW4gb3VyIGRvY3Mgb3IKaGF2ZSBzdWdnZXN0aW9ucywgcGxlYXNlIGZvbGxvdyBvdXIgW0NvbnRyaWJ1dGluZyBHdWlkZV0oQ09OVFJJQlVUSU5HLm1kKSB0bwpzdWJtaXQgYW4gaXNzdWUgb3IgcHVsbCByZXF1ZXN0LgoKRm9yIGluZm9ybWF0aW9uIG9uIHRoZSBpbnRlcm5hbCBwcm9jZXNzIG9mIG1hbmFnaW5nIHBhZ2VzLCBzZWUKW1JFQURNRS1kZXYubWRdKFJFQURNRS1kZXYubWQpLgoKW2RvY3Mtd2Vic2l0ZV06IGh0dHBzOi8vZG9jcy5zZW1hcGhvcmVjaS5jb20K")
      end
    end

    context "fetching non existing commit", :vcr => vcr_good_credentials do
      before do
        user = FactoryBot.create(:user)
        user.repo_host_accounts << FactoryBot.create(:repo_host_account)
        repository = FactoryBot.create(:repository, :integration_type => "github_oauth_token")
        project = FactoryBot.create(:project, :creator => user, :repository => repository)
        repository.update(:owner => "semaphoreci", :name => "docs")

        @req = InternalApi::RepositoryIntegrator::GetFileRequest.new(
          :project_id => project.id,
          :path => "README.md2",
          :ref => "30162c55162a184131b5d5c56f2eed78493e5c71"
        )
      end

      it "raise an exception" do
        expect do
          server.get_file(@req, call)
        end.to raise_exception(GRPC::NotFound, "5:No commit found for the ref 30162c55162a184131b5d5c56f2eed78493e5c71")
      end
    end

    context "fetching non existing file", :vcr => vcr_good_credentials do
      before do
        user = FactoryBot.create(:user)
        user.repo_host_accounts << FactoryBot.create(:repo_host_account)
        repository = FactoryBot.create(:repository, :integration_type => "github_oauth_token")
        project = FactoryBot.create(:project, :creator => user, :repository => repository)
        repository.update(:owner => "semaphoreci", :name => "docs")

        @req = InternalApi::RepositoryIntegrator::GetFileRequest.new(
          :project_id => project.id,
          :path => "README.md2",
          :ref => "c909fb301e5ae69d9835f4fdd1a646bb5c993a77"
        )
      end

      it "raise an exception" do
        expect do
          server.get_file(@req, call)
        end.to raise_exception(GRPC::NotFound, "5:Not Found")
      end
    end
  end

  describe "#get_token" do
    context "fetching oauth token with user_id" do
      before do
        @token = token
        user = FactoryBot.create(:user)
        user.repo_host_accounts << FactoryBot.create(:repo_host_account, :token => @token)

        @req = InternalApi::RepositoryIntegrator::GetTokenRequest.new(
          :integration_type => :GITHUB_OAUTH_TOKEN,
          :user_id => user.id
        )
      end

      it "returns user github oauth token" do
        response = server.get_token(@req, call)

        expect(response.token).to eq(@token)
        expect(response.expires_at).to be_nil
      end
    end

    context "fetching app token with repositry slug" do
      before do
        allow_any_instance_of(::Semaphore::ProjectIntegrationToken).to receive(:github_app_token).with(repository_slug) {
                                                                         [token, expires_at]
                                                                       }

        @req = InternalApi::RepositoryIntegrator::GetTokenRequest.new(
          :integration_type => :GITHUB_APP,
          :repository_slug => repository_slug
        )
      end

      it "returns github app token for a repository" do
        response = server.get_token(@req, call)

        expect(response.token).to eq(token)
        expect(response.expires_at).to eq(Google::Protobuf::Timestamp.new(:seconds => expires_at.to_i))
      end
    end

    context "fetching token with project id" do
      before do
        project = FactoryBot.create(:project)

        allow_any_instance_of(::Semaphore::ProjectIntegrationToken).to receive(:project_token).with(project) {
                                                                         [token, expires_at]
                                                                       }

        @req = InternalApi::RepositoryIntegrator::GetTokenRequest.new(
          :project_id => project.id
        )
      end

      it "returns github app token for a repository" do
        response = server.get_token(@req, call)

        expect(response.token).to eq(token)
        expect(response.expires_at).to eq(Google::Protobuf::Timestamp.new(:seconds => expires_at.to_i))
      end
    end

    context "fetching token for not existing user" do
      before do
        @req = InternalApi::RepositoryIntegrator::GetTokenRequest.new(
          :user_id => non_existing_id,
          :integration_type => :GITHUB_OAUTH_TOKEN
        )
      end

      it "raises an exception" do
        expect do
          server.get_token(@req, call)
        end.to raise_exception(GRPC::NotFound, "5:User with id #{non_existing_id} not found.")
      end
    end

    context "fetching token for not existing project" do
      before do
        @req = InternalApi::RepositoryIntegrator::GetTokenRequest.new(
          :project_id => non_existing_id
        )
      end

      it "raises an exception" do
        expect do
          server.get_token(@req, call)
        end.to raise_exception(GRPC::NotFound, "5:Project with id #{non_existing_id} not found.")
      end
    end

    context "fetching user token for github app" do
      before do
        user = FactoryBot.create(:user)
        user.repo_host_accounts << FactoryBot.create(:repo_host_account, :token => token)

        @req = InternalApi::RepositoryIntegrator::GetTokenRequest.new(
          :user_id => user.id,
          :integration_type => :GITHUB_APP
        )
      end

      it "raises an exception" do
        expect do
          server.get_token(@req, call)
        end.to raise_exception(GRPC::FailedPrecondition)
      end
    end

    context "fetching token without params" do
      before do
        @req = InternalApi::RepositoryIntegrator::GetTokenRequest.new
      end

      it "raises an exception" do
        expect do
          server.get_token(@req, call)
        end.to raise_exception(GRPC::FailedPrecondition)
      end
    end
  end

  describe "#get_repositories" do
    context "when user doesn't exists" do
      before do
        @req = InternalApi::RepositoryIntegrator::GetRepositoriesRequest.new(
          :user_id => non_existing_id
        )
      end

      it "returns empty list" do
        response = server.get_repositories(@req, call)

        expect(response.repositories).to eq([])
      end
    end

    context "when user exists" do
      before do
        user = FactoryBot.create(:user, :github_connection)
        GithubAppCollaborator.create!(
          :c_id => user.github_repo_host_account.github_uid,
          :c_name => user.github_repo_host_account.login,
          :r_name => "renderedtext/guard",
          :installation => GithubAppInstallation.create(:installation_id => 1)
        )

        @req = InternalApi::RepositoryIntegrator::GetRepositoriesRequest.new(
          :user_id => user.id
        )
      end

      it "returns list of repositories" do
        response = server.get_repositories(@req, call)

        expect(response.repositories).to eq([
                                              InternalApi::RepositoryIntegrator::Repository.new(
                                                :addable => true,
                                                :name => "guard",
                                                :url => "git://github.com/renderedtext/guard.git",
                                                :full_name => "renderedtext/guard",
                                                :description => ""
                                              )
                                            ])
      end
    end
  end

  describe "#check_token" do
    context "for github app integration" do
      before do
        repository = FactoryBot.create(:repository, :integration_type => "github_app")
        @project = FactoryBot.create(:project, :repository => repository)

        @req = InternalApi::RepositoryIntegrator::CheckTokenRequest.new(
          :project_id => @project.id
        )
      end

      context "when there is no app instalation for a repository" do
        it "returns as invalid with no connection" do
          response = server.check_token(@req, call)

          expect(response.valid).to be(false)
          expect(response.integration_scope).to eq(:NO_CONNECTION)
        end
      end

      context "when there is an app instalation for a repository" do
        before do
          FactoryBot.create(:github_app_installation, :repositories => [@project.repo_owner_and_name])
        end

        it "returns as valid with full connection" do
          response = server.check_token(@req, call)

          expect(response.valid).to be(true)
          expect(response.integration_scope).to eq(:FULL_CONNECTION)
        end
      end
    end

    context "for github app integration" do
      let(:token_valid) { true }
      let(:repository_private) { true }
      let(:permission_scope) { "user:email" }

      before do
        user = FactoryBot.create(:user)
        user.repo_host_accounts << FactoryBot.create(:repo_host_account, :permission_scope => permission_scope)
        repository = FactoryBot.create(:repository, :private => repository_private,
                                                    :integration_type => "github_oauth_token")
        @project = FactoryBot.create(:project, :creator => user, :repository => repository)

        allow_any_instance_of(RepoHost::Github::Client).to receive(:token_valid?) { token_valid }

        @req = InternalApi::RepositoryIntegrator::CheckTokenRequest.new(
          :project_id => @project.id
        )
      end

      context "when token is revoked" do
        let(:token_valid) { false }

        before do
          @project.repo_host_account.update!(:revoked => true)
        end

        it "returns as invalid with no connection" do
          response = server.check_token(@req, call)

          expect(response.valid).to be(false)
          expect(response.integration_scope).to eq(:NO_CONNECTION)
        end
      end

      context "when there is no project" do
        it "returns project not found error" do
          req = InternalApi::RepositoryIntegrator::CheckTokenRequest.new(
            :project_id => "3e36fbc9-23fd-4e32-89a7-64dfa722707e"
          )

          expect do
            server.check_token(req, call)
          end.to raise_exception(GRPC::NotFound)
        end
      end

      context "when repository is private" do
        let(:repository_private) { true }

        context "when token has only email scope" do
          let(:permission_scope) { "user:email" }

          it "returns invalid token with no connection" do
            response = server.check_token(@req, call)

            expect(response.valid).to be(false)
            expect(response.integration_scope).to eq(:NO_CONNECTION)
          end
        end

        context "when token has public scope" do
          let(:permission_scope) { "public_repo,user:email" }

          it "returns invalid token with only public connection" do
            response = server.check_token(@req, call)

            expect(response.valid).to be(false)
            expect(response.integration_scope).to eq(:ONLY_PUBLIC)
          end
        end

        context "when token has private scope" do
          let(:permission_scope) { "repo,user:email" }

          it "returns valid token with full connection" do
            response = server.check_token(@req, call)

            expect(response.valid).to be(true)
            expect(response.integration_scope).to eq(:FULL_CONNECTION)
          end
        end
      end

      context "when repository is public" do
        let(:repository_private) { false }

        context "when token has only email scope" do
          let(:permission_scope) { "user:email" }

          it "returns invalid token with no connection" do
            response = server.check_token(@req, call)

            expect(response.valid).to be(false)
            expect(response.integration_scope).to eq(:NO_CONNECTION)
          end
        end

        context "when token has public scope" do
          let(:permission_scope) { "public_repo,user:email" }

          it "returns valid token with only public" do
            response = server.check_token(@req, call)

            expect(response.valid).to be(true)
            expect(response.integration_scope).to eq(:ONLY_PUBLIC)
          end
        end

        context "when token has private scope" do
          let(:permission_scope) { "repo,user:email" }

          it "returns valid token with full connection" do
            response = server.check_token(@req, call)

            expect(response.valid).to be(true)
            expect(response.integration_scope).to eq(:FULL_CONNECTION)
          end
        end
      end
    end
  end

  describe "#github_installation_info" do
    before do
      Semaphore::GithubApp::Credentials.instance_variable_set(:@github_application_url, nil)
      repository = FactoryBot.create(:repository, :integration_type => "github_app")
      @project = FactoryBot.create(:project, :repository => repository)

      @req = InternalApi::RepositoryIntegrator::GithubInstallationInfoRequest.new(
        :project_id => @project.id
      )
    end

    context "when there is no app instalation for a repository" do
      it "returns as invalid with no connection" do
        response = server.github_installation_info(@req, call)

        expect(response.installation_id).to eq(0)
        expect(response.installation_url).to eq("")
        expect(response.application_url).to eq(Semaphore::GithubApp::Credentials.github_application_url)
      end
    end

    context "when there is no project" do
      it "returns project not found error" do
        req = InternalApi::RepositoryIntegrator::GithubInstallationInfoRequest.new(
          :project_id => "3e36fbc9-23fd-4e32-89a7-64dfa722707e"
        )

        expect do
          server.github_installation_info(req, call)
        end.to raise_exception(GRPC::NotFound)
      end
    end

    context "when there is an app instalation for a repository" do
      before do
        @installation = FactoryBot.create(:github_app_installation, :repositories => [@project.repo_owner_and_name])
      end

      it "returns as valid with full connection" do
        response = server.github_installation_info(@req, call)

        expect(response.installation_id).to eq(@installation.installation_id)
        expect(response.installation_url).to eq("https://github.com/organizations/renderedtext/settings/installations/#{@installation.installation_id}")
        expect(response.application_url).to eq(Semaphore::GithubApp::Credentials.github_application_url)
      end
    end
  end
end
