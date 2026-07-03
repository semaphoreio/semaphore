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
    before do
      # Credentials prefer Local (env/App config), so clear it — and the memoized
      # values — to exercise the InstanceConfig fallback.
      Semaphore::GithubApp::Credentials.instance_variable_set(:@github_client_id, nil)
      Semaphore::GithubApp::Credentials.instance_variable_set(:@github_client_secret, nil)
      allow(Semaphore::GithubApp::Credentials::Local).to receive_messages(:github_client_id => nil, :github_client_secret => nil)
    end

    it "falls back to InstanceConfigClient credentials when local config is unset" do
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

    context "when unhandled octokit exception occurs" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:repositories)
          .and_raise(Octokit::TooManyLoginAttempts)
      end

      it "raises semaphore's RepoHost::RemoteException::NotFound" do
        expect do
          @client.repositories
        end.to raise_error(RepoHost::RemoteException::Unknown)
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

    context "when create_ref encounters 'Reference already exists' (idempotent)" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_ref)
          .and_raise(
            Octokit::UnprocessableEntity.new(
              :status => 422,
              :body => "Reference already exists"
            )
          )
      end

      it "raises RepoHost::RemoteException::ReferenceAlreadyExists so callers can handle the idempotent case explicitly" do
        expect do
          @client.create_ref("repo", "refs/semaphoreci/abc", "abc")
        end.to raise_error(RepoHost::RemoteException::ReferenceAlreadyExists)
      end
    end

    context "when create_ref encounters 'Reference already exists' wrapped in Octokit's full message format" do
      # Real Octokit constructs the exception message by prefixing the request
      # method/URL and HTTP status before the API body. This test guards
      # against the matcher silently breaking if `:body =>` and the real
      # `.message` ever diverge.
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_ref)
          .and_raise(
            Octokit::UnprocessableEntity.new(
              :status => 422,
              :body => "POST https://api.github.com/repos/owner/repo/git/refs: 422 - Reference already exists // See: https://docs.github.com/rest"
            )
          )
      end

      it "still raises ReferenceAlreadyExists" do
        expect do
          @client.create_ref("repo", "refs/semaphoreci/abc", "abc")
        end.to raise_error(RepoHost::RemoteException::ReferenceAlreadyExists)
      end
    end

    context "when create_ref encounters an unrelated 422" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_ref)
          .and_raise(
            Octokit::UnprocessableEntity.new(
              :status => 422,
              :body => "Invalid object SHA"
            )
          )
      end

      it "raises RepoHost::RemoteException::Unknown so the caller sees the failure" do
        expect do
          @client.create_ref("repo", "refs/semaphoreci/abc", "abc")
        end.to raise_error(RepoHost::RemoteException::Unknown)
      end
    end

    context "when create_ref encounters TooManyRequests" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_ref)
          .and_raise(Octokit::TooManyRequests)
      end

      it "propagates as RepoHost::RemoteException::TooManyRequests rather than swallowing" do
        expect do
          @client.create_ref("repo", "refs/semaphoreci/abc", "abc")
        end.to raise_error(RepoHost::RemoteException::TooManyRequests)
      end
    end
  end

  describe "#compare" do
    it "fetches the comparison through a non-paginating client" do
      non_paginating = instance_double(Octokit::Client)
      allow(Octokit::Client).to receive(:new)
        .with(hash_including(:auto_paginate => false))
        .and_return(non_paginating)
      allow(non_paginating).to receive(:compare).and_return(:comparison)

      expect(@client.compare("owner/repo", "basesha", "main")).to eq(:comparison)
      expect(non_paginating).to have_received(:compare).with("owner/repo", "basesha", "main")
    end

    it "escapes URL-significant ref characters, preserving namespace slashes" do
      non_paginating = instance_double(Octokit::Client)
      allow(Octokit::Client).to receive(:new)
        .with(hash_including(:auto_paginate => false))
        .and_return(non_paginating)
      allow(non_paginating).to receive(:compare).and_return(:comparison)

      @client.compare("owner/repo", "basesha", "release/feat#1")

      expect(non_paginating).to have_received(:compare)
        .with("owner/repo", "basesha", "release/feat%231")
    end

    it "translates a missing ref into RepoHost::RemoteException::NotFound" do
      allow_any_instance_of(Octokit::Client).to receive(:compare)
        .and_raise(Octokit::NotFound)

      expect do
        @client.compare("owner/repo", "basesha", "missing-branch")
      end.to raise_error(RepoHost::RemoteException::NotFound)
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

  describe "#push_access_to_organization?", :aggregate_failures do
    def repo(login, type, push)
      { :owner => { :login => login, :type => type }, :permissions => { :push => push } }
    end

    it "is true when the user has push to a repo owned by the org (case-insensitive)" do
      allow_any_instance_of(Octokit::Client).to receive(:repos).and_return([repo("Acme", "Organization", true)])

      expect(@client.push_access_to_organization?("acme")).to be(true)
    end

    it "is false when the user only has pull access in the org" do
      allow_any_instance_of(Octokit::Client).to receive(:repos).and_return([repo("acme", "Organization", false)])

      expect(@client.push_access_to_organization?("acme")).to be(false)
    end

    it "ignores push repos owned by a different org or a personal account" do
      allow_any_instance_of(Octokit::Client).to receive(:repos)
        .and_return([repo("other", "Organization", true), repo("acme", "User", true)])

      expect(@client.push_access_to_organization?("acme")).to be(false)
    end

    it "is false when the user has no accessible repositories" do
      allow_any_instance_of(Octokit::Client).to receive(:repos).and_return([])

      expect(@client.push_access_to_organization?("acme")).to be(false)
    end

    it "fails closed when the GitHub call times out" do
      allow_any_instance_of(Octokit::Client).to receive(:repos).and_raise(Faraday::TimeoutError)

      expect(@client.push_access_to_organization?("acme")).to be(false)
    end

    it "builds the scan client with request timeouts" do
      allow(Octokit::Client).to receive(:new).and_return(instance_double(Octokit::Client, :repos => []))

      expect(@client.push_access_to_organization?("acme")).to be(false)
      expect(Octokit::Client).to have_received(:new).with(
        hash_including(
          :connection_options => {
            :request => {
              :open_timeout => described_class::ORG_PUSH_OPEN_TIMEOUT,
              :timeout => described_class::ORG_PUSH_READ_TIMEOUT
            }
          }
        )
      )
    end

    it "scans only organization-member repositories (excludes outside collaborators)" do
      scan_client = instance_double(Octokit::Client)
      allow(Octokit::Client).to receive(:new).and_return(scan_client)
      allow(scan_client).to receive(:repos).and_return([])

      @client.push_access_to_organization?("acme")

      expect(scan_client).to have_received(:repos).with(
        nil, hash_including(:affiliation => "organization_member")
      )
    end
  end
end
