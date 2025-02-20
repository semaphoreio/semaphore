require "spec_helper"

RSpec.describe RepoHost::Github::Client do
  let(:token) { "123" }
  let(:client_stub) { instance_double(InternalApi::InstanceConfig::InstanceConfigService::Stub) }
  let(:mock_response) do
    InternalApi::InstanceConfig::ListConfigsResponse.new(
      configs: [
        InternalApi::InstanceConfig::Config.new(
          type: InternalApi::InstanceConfig::ConfigType::CONFIG_TYPE_GITHUB_APP,
          state: InternalApi::InstanceConfig::State::STATE_CONFIGURED,
          fields: [
            InternalApi::InstanceConfig::ConfigField.new(key: "pem", value: "pem_value"),
            InternalApi::InstanceConfig::ConfigField.new(key: "html_url", value: "url_value"),
            InternalApi::InstanceConfig::ConfigField.new(key: "app_id", value: "123"),
            InternalApi::InstanceConfig::ConfigField.new(key: "client_id", value: "instance_client_id"),
            InternalApi::InstanceConfig::ConfigField.new(key: "client_secret", value: "instance_client_secret")
          ]
        )
      ]
    )
  end

  before do
    @client = RepoHost::Github::Client.new(token)
    allow(InternalApi::InstanceConfig::InstanceConfigService::Stub).to receive(:new).and_return(client_stub)
    allow(client_stub).to receive(:list_configs).and_return(mock_response)
  end

  describe "#app_client" do
    it "gets credentials from Semaphore::GithubApp::Credentials::InstanceConfigClient when instance config credentials are set" do
      client = RepoHost::Github::Client.new(token)
      app_client = client.send(:app_client)

      expect(app_client.client_id).to eq("instance_client_id")
      expect(app_client.client_secret).to eq("instance_client_secret")
    end
  end

  describe "translating Octokit exceptions to Semaphore exceptions" do
    context "when maximum number of API requests exception occurs" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_status)
          .and_raise(Octokit::TooManyRequests)
      end

      it "raises semaphore's RepoHost::RemoteException::TooManyRequests" do
        expect do
          @client.create_status("semaphore", "asdf234321", "passed", {})
        end.to raise_error(RepoHost::RemoteException::TooManyRequests)
      end
    end

    context "when github says forbidden" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_status)
          .and_raise(Octokit::Forbidden)
      end

      it "raises semaphore's RepoHost::RemoteException::Unauthorized" do
        expect do
          @client.create_status("semaphore", "asdf234321", "passed", {})
        end.to raise_error(RepoHost::RemoteException::Unauthorized)
      end
    end

    context "when maximum number of statuses exception occurs" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_status)
          .and_raise(
            Octokit::UnprocessableEntity.new(
              :status => 422,
              :body => "This SHA and context has reached the maximum number of statuses."
            )
          )
      end

      it "raises semaphore's RepoHost::RemoteException::MaximumNumberOfStatuses" do
        expect do
          @client.create_status("semaphore", "asdf234321", "passed", {})
        end.to raise_error(RepoHost::RemoteException::MaximumNumberOfStatuses)
      end
    end

    context "when octokit unauthorized exception occurs" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:repositories)
          .and_raise(Octokit::Unauthorized)
      end

      it "raises semaphore's RepoHost::RemoteException::Unauthorized" do
        expect do
          @client.repositories
        end.to raise_error(RepoHost::RemoteException::Unauthorized)
      end
    end

    context "when octokit not found exception occurs" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:repositories)
          .and_raise(Octokit::NotFound)
      end

      it "raises semaphore's RepoHost::RemoteException::NotFound" do
        expect do
          @client.repositories
        end.to raise_error(RepoHost::RemoteException::NotFound)
      end
    end

    context "when repository hook already exists on GitHub" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_hook)
          .and_raise(
            Octokit::UnprocessableEntity.new(
              :status => 422,
              :body => "Hook already exists on this repository"
            )
          )
      end

      it "raises semaphore's RepoHost::RemoteException::NotFound" do
        expect do
          @client.create_hook("repo", "id", "config")
        end.to raise_error(RepoHost::RemoteException::HookExistsOnRepository)
      end
    end
  end

  describe "#token_valid?" do
    before { @client = RepoHost::Github::Client.new("token") }

    context "token is valid" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:check_application_authorization)
          .and_return("S'allright.")
      end

      it "returns true" do
        expect(@client.token_valid?).to eql(true)
      end
    end

    context "token is invalid" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:check_application_authorization)
          .and_raise(Octokit::NotFound)
      end

      it "returns false" do
        expect(@client.token_valid?).to eql(false)
      end
    end

    context "token is nil" do
      it "returns false" do
        client = RepoHost::Github::Client.new(nil)
        expect(client.token_valid?).to eql(false)
      end
    end
  end

  describe "#revoke_connection" do
    let(:authorization_id) { 42 }

    before { @client = RepoHost::Github::Client.new(token) }

    context "operation successfull" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:revoke_application_authorization)
          .and_return(true)
      end

      it "returns true" do
        expect(@client.revoke_connection).to eql(true)
      end
    end

    context "coperation unsuccessfull" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:revoke_application_authorization)
          .and_return(false)
      end

      it "returns false" do
        expect(@client.revoke_connection).to eql(false)
      end
    end
  end

  context "interaction with GitHub repositories" do
    context "account allowing public access to the GitHub API",
            :vcr => {
              :allow_playback_repeats => true,
              :cassette_name => "Github/Client/public_repositories"
            } do

      before do
        @public_repo_host_account = FactoryBot.create(:github_account_marvin)
        @github_client = RepoHost::Factory.create_repo_host(@public_repo_host_account)
      end

      #
      # this GitHub account has only one repo called "base-app"
      #
      describe "#repositories" do
        before do
          pending("for some reason failing after moving project to alles")
          @repositories = @github_client.repositories
          @repo = @repositories.first
        end

        it "fetches only the repository owned by the user" do
          expected_owner = @public_repo_host_account.login

          expect(@repo[:owner][:login]).to eq expected_owner
          expect(@repositories.count).to eq 1
          expect(@repo[:name]).to eq "base-app"
        end

        it "fetches the public repos owned by the user" do
          expect(@repo[:private]).to be_falsy
        end
      end

      #
      # this GitHub account is part of two organizations:
      # - willscorp (1 org repo ["warpdrive"])
      #
      describe "#group_repositories" do
        before do
          pending("for some reason failing after moving project to alles")
          @repositories = @github_client.group_repositories
          @repo = @repositories.first
        end

        it "lists only writable org repos" do
          expect(@repo.name).to eq "warpdrive"
          expect(@repositories.count).to eq 1
        end

        context "user is part of an org withtout repos" do
          before do
            allow_any_instance_of(Octokit::Client).to receive(:repositories).and_return([])
            @repositories = @github_client.group_repositories
          end

          it "returns an empty array" do
            expect(@repositories).to be_an_instance_of(Array)
            expect(@repositories).to be_empty
          end
        end
      end
    end
  end
end
