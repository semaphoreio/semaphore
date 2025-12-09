require "spec_helper"

RSpec.describe ProjectsController, :type => :controller do
  def post_payload(payload)
    post :repo_host_post_commit_hook, :params => { :payload => payload,
                                                   :hash_id => "570df438-3a41-4859-b714-cc2ea4e9c49d" }
  end

  def post_app_payload(payload)
    post :repo_host_post_commit_hook, :params => { :payload => payload }
  end

  let(:project) { double(Project, :id => 123123, :name => "") }
  let(:installation_target_type) { "repository" }

  before do
    allow(Watchman).to receive(:increment)
    allow(Watchman).to receive(:submit)
  end

  describe "POST repo_host_post_commit_hook" do
    before do
      allow(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_async)
    end

    context "when App.ee? is true and license is valid" do
      before do
        allow(App).to receive(:ee?).and_return(true)
        # Stub check_license! to simulate valid license (do nothing)
        allow(LicenseVerifier).to receive(:verify).and_return(true)
        allow(Semaphore::RepoHost::Hooks::Request).to receive_messages(new: double(delivery_id: "123"), normalize_params: { payload: "{}" })
        allow(Semaphore::RepoHost::WebhookFilter).to receive(:create_webhook_filter).and_return(double(
                                                                                                  unsupported_webhook?: true,
                                                                                                  github_app_webhook?: false,
                                                                                                  github_app_installation_webhook?: false
                                                                                                ))
        allow_any_instance_of(Logman).to receive(:add)
        allow_any_instance_of(Logman).to receive(:info)
        allow_any_instance_of(Logman).to receive(:error)
      end

      it "processes the hook and returns 200 OK" do
        post :repo_host_post_commit_hook, params: { payload: "{}" }
        expect(response).to have_http_status(:ok)
      end
    end

    context "when App.ee? is true and license is invalid" do
      before do
        allow(App).to receive(:ee?).and_return(true)
        # Simulate check_license! to simulate invalid license
        allow(LicenseVerifier).to receive(:verify).and_return(false)
        allow(Semaphore::RepoHost::Hooks::Request).to receive_messages(new: double(delivery_id: "123"), normalize_params: { payload: "{}" })
        allow(Semaphore::RepoHost::WebhookFilter).to receive(:create_webhook_filter).and_return(double(
                                                                                                  unsupported_webhook?: true,
                                                                                                  github_app_webhook?: false,
                                                                                                  github_app_installation_webhook?: false
                                                                                                ))
        allow_any_instance_of(Logman).to receive(:add)
        allow_any_instance_of(Logman).to receive(:info)
        allow_any_instance_of(Logman).to receive(:error)
      end

      it "refuses processing and returns 403 Forbidden" do
        post :repo_host_post_commit_hook, params: { payload: "{}" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when GitHub hook" do
      let(:workflow) { double(Workflow, :id => 111, :update_attribute => nil) }
      let(:payload) { RepoHost::Github::Responses::Payload.post_receive_hook_pull_request }
      let(:signature) do
        "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), "secret", payload)}"
      end
      let(:payload_request) do
        body = StringIO.new
        body.puts payload

        double("Request", :headers => {
                 "User-Agent" => "GitHub-Hookshot/xxx",
                 "X-Github-Event" => event,
                 "X-GitHub-Hook-Installation-Target-Type" => installation_target_type,
                 "X-Hub-Signature-256" => signature
               }, :body => body, :raw_post => "Hello, World!")
      end

      before do
        allow(controller).to receive(:repo_host_request) { payload_request }
        allow(Semaphore::RepoHost::Hooks::Recorder).to receive(:record_hook).and_return(workflow)
        allow(Semaphore::RepoHost::Hooks::Handler).to receive(:enqueue_job)
        allow(Semaphore::GithubApp::Credentials).to receive(:github_app_webhook_secret).and_return("secret")

        @organization = FactoryBot.create(:organization)
        @project = FactoryBot.create(:project,
                                     :id => "570df438-3a41-4859-b714-cc2ea4e9c49d",
                                     :organization => @organization)
      end

      context "when project is not found" do
        let(:event) { "push" }

        it "returns ok" do
          post :repo_host_post_commit_hook, :params => {
            :payload => payload,
            :hash_id => SecureRandom.uuid # sending ID of a non-existing project
          }

          expect(response).to be_not_found
        end

        it "doesn't record a hook" do
          @organization.update(:suspended => true)
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload(payload)
        end
      end

      context "when organization is suspended" do
        let(:event) { "push" }

        it "returns ok" do
          post_payload(payload)

          expect(response).to be_ok
        end

        it "doesn't record a hook" do
          @organization.update(:suspended => true)
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload(payload)
        end
      end

      context "when push event occurs" do
        let(:event) { "push" }

        it "doesn't required authenticated_user" do
          expect(controller).not_to receive(:authenticate_user!)

          post_payload(payload)
        end

        it "doesn't publish event" do
          expect(Tackle).not_to receive(:publish)
          expect(Semaphore::Events::RemoteRepositoryChanged).to receive(:emit)
          expect(Semaphore::GithubApp::Collaborators::Worker).not_to receive(:perform_async)

          post_payload(payload)
        end

        it "saves the hook payload" do
          expect(Semaphore::RepoHost::Hooks::Recorder).to receive(:record_hook)

          post_payload(payload)
        end

        it "calls execute on post commit service" do
          expect(Semaphore::RepoHost::Hooks::Recorder).to receive(:record_hook).and_return(workflow)
          expect(Semaphore::RepoHost::Hooks::Handler::Worker).to receive(:perform_async).with(111, "Hello, World!", signature, 0)

          post_payload(payload)
        end

        it "saves workflow's result as OK" do
          expect(workflow).to receive(:update_attribute).with(:result, Workflow::RESULT_OK)

          post_payload(payload)
        end

        it "responds with OK" do
          post_payload(payload)

          expect(response).to be_ok
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_payload(payload)
        end

        it "increments the handled hooks count" do
          expect(Watchman).to receive(:increment).with("IncommingHooks.processed", { external: true }).and_call_original

          post_payload(payload)
        end

        it "increments the external metric for handled hooks count" do
          expect(Watchman).to receive(:increment).with("IncommingHooks.received", { external: true }).and_call_original

          post_payload(payload)
        end
      end

      context "when issue comment event occurs" do
        let(:event) { "issue_comment" }
        let(:payload) { RepoHost::Github::Responses::Payload.post_receive_hook_issue_comment }

        it "doesn't required authenticated_user" do
          expect(controller).not_to receive(:authenticate_user!)

          post_payload(payload)
        end

        it "doesn't publish event" do
          expect(Tackle).not_to receive(:publish)
          expect(Semaphore::Events::RemoteRepositoryChanged).to receive(:emit)
          expect(Semaphore::GithubApp::Collaborators::Worker).not_to receive(:perform_async)

          post_payload(payload)
        end

        it "saves the hook payload" do
          expect(Semaphore::RepoHost::Hooks::Recorder).to receive(:record_hook)

          post_payload(payload)
        end

        it "calls execute on post commit service" do
          expect(Semaphore::RepoHost::Hooks::Recorder).to receive(:record_hook).and_return(workflow)
          expect(Semaphore::RepoHost::Hooks::Handler::Worker).to receive(:perform_async).with(111, "Hello, World!", signature, 0)

          post_payload(payload)
        end

        it "saves workflow's result as OK" do
          expect(workflow).to receive(:update_attribute).with(:result, Workflow::RESULT_OK)

          post_payload(payload)
        end

        it "responds with OK" do
          post_payload(payload)

          expect(response).to be_ok
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_payload(payload)
        end

        it "increments the handled hooks count" do
          expect(Watchman).to receive(:increment).with("IncommingHooks.processed", { external: true }).and_call_original

          post_payload(payload)
        end

        it "increments the external metric for hooks count" do
          expect(Watchman).to receive(:increment).with("IncommingHooks.received", { external: true }).and_call_original

          post_payload(payload)
        end
      end

      context "when pull request within repo occurs" do
        let(:event) { "pull_request" }

        it "doesn't publish event" do
          expect(Tackle).not_to receive(:publish)
          expect(Semaphore::Events::RemoteRepositoryChanged).to receive(:emit)
          expect(Semaphore::GithubApp::Collaborators::Worker).not_to receive(:perform_async)

          post_payload(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request_within_repo)
        end

        it "response with head ok" do
          post_payload(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request_within_repo)

          expect(response).to be_ok
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_payload(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request_within_repo)
        end

        it "increments the unsupported_webhook count" do
          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.unsupported_webhook").and_call_original

          post_payload(RepoHost::Github::Responses::Payload.pull_request_assigned)
        end
      end

      context "when member event occurs" do
        let(:event) { "member" }

        it "response with head ok" do
          post_payload(RepoHost::Github::Responses::Payload.post_receive_hook_member)

          expect(response).to be_ok
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_payload(RepoHost::Github::Responses::Payload.post_receive_hook_member)
        end

        it "increments the member_webhook count" do
          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.member_webhook").and_call_original

          post_payload(RepoHost::Github::Responses::Payload.post_receive_hook_member)
        end

        it "publish event" do
          repository = double("Repository", :id => "repo-123")
          project = double(Project, :id => "96b0a57c-d9ae-453f-b56f-3b154eb10cda", :organization => @organization,
                                    :repo_owner_and_name => "foo/bar", :repository => repository)
          expect(Project).to receive(:find_by).and_return(project)

          expect(Semaphore::Events::ProjectCollaboratorsChanged).to receive(:emit).and_call_original
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_async)

          post_payload(RepoHost::Github::Responses::Payload.post_receive_hook_member)
        end
      end

      context "when repository event occurs" do
        let(:event) { "repository" }
        let(:installation_target_type) { "integration" }
        let(:payload) { RepoHost::Github::Responses::Payload.repository_renamed_app_hook }

        it "response with head ok" do
          post_payload(payload)

          expect(response).to be_ok
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_payload(payload)
        end

        it "increments the repository_webhook count" do
          allow(Watchman).to receive(:increment)

          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.github_app_webhook").and_call_original
          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.repository_webhook").and_call_original

          post_payload(payload)
        end

        it "perform repository sync" do
          expect(Semaphore::GithubApp::Repositories::Worker).to receive(:perform_async).and_call_original

          post_payload(payload)
        end
      end

      context "when repository renamed event occurs" do
        let(:event) { "repository" }
        let(:payload) { RepoHost::Github::Responses::Payload.repository_renamed_hook }

        it "response with head ok" do
          post_payload(payload)

          expect(response).to be_ok
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_payload(payload)
        end

        it "increments the repository_renamed_webhook count" do
          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.repository_webhook").and_call_original

          post_payload(payload)
        end

        it "publish event" do
          repository = double(Repository, :id => "repo-123")
          project = double(Project, :id => "96b0a57c-d9ae-453f-b56f-3b154eb10cda", :organization => @organization,
                                    :repo_owner => "foo", :repository => repository)
          expect(Project).to receive(:find_by).and_return(project)

          expect(Semaphore::RepoHost::Hooks::Handler).to receive(:webhook_signature_valid?).with(
            anything,
            project.organization.id,
            project.repository.id,
            anything,
            anything
          ).and_return(true)

          expect(Semaphore::Events::RemoteRepositoryChanged).to receive(:emit).and_call_original

          post_payload(payload)
        end
      end

      context "when default branch changed event occurs" do
        let(:event) { "repository" }
        let(:payload) { RepoHost::Github::Responses::Payload.default_branch_changed }

        it "response with head ok" do
          post_payload(payload)

          expect(response).to be_ok
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_payload(payload)
        end

        it "increments the default_branch_changed count" do
          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.repository_webhook").and_call_original

          post_payload(payload)
        end

        it "publish event" do
          repository = double(Repository, :id => "repo-123")
          project = double(Project, :id => "96b0a57c-d9ae-453f-b56f-3b154eb10cda", :organization => @organization,
                                    :repo_owner_and_name => "foo/bar", :repository => repository)
          expect(Project).to receive(:find_by).and_return(project)

          expect(Semaphore::RepoHost::Hooks::Handler).to receive(:webhook_signature_valid?).with(
            anything,
            project.organization.id,
            project.repository.id,
            anything,
            anything
          ).and_return(true)

          expect(Semaphore::Events::RemoteRepositoryChanged).to receive(:emit).and_call_original

          post_payload(payload)
        end

        it "does not publish event when signature is invalid" do
          repository = double("Repository", :id => "repo-123")
          project = double(Project, :id => "96b0a57c-d9ae-453f-b56f-3b154eb10cda", :organization => @organization,
                                    :repo_owner_and_name => "foo/bar", :repository => repository)
          expect(Project).to receive(:find_by).and_return(project)

          expect(Semaphore::RepoHost::Hooks::Handler).to receive(:webhook_signature_valid?).and_return(false)
          expect(Semaphore::Events::RemoteRepositoryChanged).not_to receive(:emit)

          post_payload(payload)
        end
      end

      context "when github_app installation event occurs" do
        let(:event) { "installation" }
        let(:payload) { RepoHost::Github::Responses::Payload.installation_created }

        it "response with head ok" do
          post_app_payload(payload)

          expect(response).to be_ok
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_app_payload(payload)
        end

        it "increments the github_app_webhook count" do
          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.github_app_webhook").and_call_original

          post_app_payload(payload)
        end

        it "calls GithubApp hook processor" do
          expect(Semaphore::GithubApp::Hook).to receive(:process).and_call_original

          post_app_payload(payload)
        end
      end

      context "when github_app installation_repositories event occurs" do
        let(:event) { "installation_repositories" }
        let(:payload) { RepoHost::Github::Responses::Payload.installation_repositories_added }

        it "response with head ok" do
          post_app_payload(payload)

          expect(response).to be_ok
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_app_payload(payload)
        end

        it "increments the github_app_webhook count" do
          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.github_app_webhook").and_call_original

          post_app_payload(payload)
        end

        it "calls GithubApp hook processor" do
          expect(Semaphore::GithubApp::Hook).to receive(:process).and_call_original

          post_app_payload(payload)
        end
      end

      context "when github_app push event occurs" do
        let(:event) { "push" }
        let(:installation_target_type) { "integration" }
        let(:payload) { RepoHost::Github::Responses::Payload.github_app_push }

        it "doesn't required authenticated_user" do
          expect(controller).not_to receive(:authenticate_user!)

          post_app_payload(payload)
        end

        it "return 404 when project is not found" do
          post_app_payload(payload)

          expect(response).to be_not_found
        end

        it "increments the github app webhook count" do
          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.github_app_webhook").and_call_original

          post_app_payload(payload)
        end

        it "saves workflow's result as OK when there is a project" do
          repository = FactoryBot.create(:repository, :name => "sandbox", :owner => "renderedtext",
                                                      :integration_type => "github_app")
          FactoryBot.create(:project, :repository => repository)

          expect(workflow).to receive(:update_attribute).with(:result, Workflow::RESULT_OK)

          post_app_payload(payload)
        end
      end

      context "when membership organization remove occurs" do
        let(:event) { "membership" }
        let(:installation_target_type) { "integration" }
        let(:payload) { RepoHost::Github::Responses::Payload.github_app_membership_organization_remove }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => 13675798)
          repository = FactoryBot.create(:repository, :name => "guard", :owner => "renderedtext",
                                                      :integration_type => "github_app")
          FactoryBot.create(:project, :repository => repository)
        end

        it "doesn't required authenticated_user" do
          expect(controller).not_to receive(:authenticate_user!)

          post_app_payload(payload)
        end

        it "doesn't publish event" do
          expect(Tackle).not_to receive(:publish)
          expect(Semaphore::GithubApp::Collaborators::Worker).not_to receive(:perform_async)

          post_payload(payload)
        end

        it "doesn't record the hook" do
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload(payload)

          expect(response).to be_ok
        end
      end

      context "when team deleted occurs" do
        let(:event) { "team" }
        let(:installation_target_type) { "integration" }
        let(:payload) { RepoHost::Github::Responses::Payload.github_app_team_deleted }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => 13675798)
          repository = FactoryBot.create(:repository, :name => "guard", :owner => "renderedtext",
                                                      :integration_type => "github_app")
          FactoryBot.create(:project, :repository => repository)
        end

        it "doesn't required authenticated_user" do
          expect(controller).not_to receive(:authenticate_user!)

          post_app_payload(payload)
        end

        it "publish event" do
          expect(Tackle).to receive(:publish).and_call_original
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_async)

          post_payload(payload)
        end

        it "doesn't record the hook" do
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload(payload)

          expect(response).to be_ok
        end
      end

      context "when team rename occurs" do
        let(:event) { "team" }
        let(:installation_target_type) { "integration" }
        let(:payload) { RepoHost::Github::Responses::Payload.github_app_team_renamed }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => 13675798)
          repository = FactoryBot.create(:repository, :name => "guard", :owner => "renderedtext",
                                                      :integration_type => "github_app")
          FactoryBot.create(:project, :repository => repository)
        end

        it "doesn't required authenticated_user" do
          expect(controller).not_to receive(:authenticate_user!)

          post_app_payload(payload)
        end

        it "doesn't publish event" do
          expect(Tackle).not_to receive(:publish)
          expect(Semaphore::GithubApp::Collaborators::Worker).not_to receive(:perform_async)

          post_payload(payload)
        end

        it "doesn't record the hook" do
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload(payload)

          expect(response).to be_ok
        end
      end

      context "when team change permissions occurs" do
        let(:event) { "team" }
        let(:installation_target_type) { "integration" }
        let(:payload) { RepoHost::Github::Responses::Payload.github_app_team_changed_permissions }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => 13675798)
          repository = FactoryBot.create(:repository, :name => "guard", :owner => "renderedtext",
                                                      :integration_type => "github_app")
          FactoryBot.create(:project, :repository => repository)
        end

        it "doesn't required authenticated_user" do
          expect(controller).not_to receive(:authenticate_user!)

          post_app_payload(payload)
        end

        it "publish event" do
          expect(Tackle).to receive(:publish).and_call_original
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_async)

          post_payload(payload)
        end

        it "doesn't record the hook" do
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload(payload)

          expect(response).to be_ok
        end
      end

      context "when team added to repo" do
        let(:event) { "team" }
        let(:installation_target_type) { "integration" }
        let(:payload) { RepoHost::Github::Responses::Payload.github_app_team_added_to_repo }

        before do
          repository = FactoryBot.create(:repository, :name => "front", :owner => "mimimalizam",
                                                      :integration_type => "github_app")
          FactoryBot.create(:project, :repository => repository)
        end

        it "doesn't required authenticated_user" do
          expect(controller).not_to receive(:authenticate_user!)

          post_app_payload(payload)
        end

        it "publish event" do
          expect(Tackle).to receive(:publish).and_call_original
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_async)

          post_payload(payload)
        end

        it "doesn't record the hook" do
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload(payload)

          expect(response).to be_ok
        end
      end

      context "when team removed from repo" do
        let(:event) { "team" }
        let(:installation_target_type) { "integration" }
        let(:payload) { RepoHost::Github::Responses::Payload.github_app_team_removed_from_repo }

        before do
          repository = FactoryBot.create(:repository, :name => "front", :owner => "renderedtext",
                                                      :integration_type => "github_app")
          FactoryBot.create(:project, :repository => repository)
        end

        it "doesn't required authenticated_user" do
          expect(controller).not_to receive(:authenticate_user!)

          post_app_payload(payload)
        end

        it "publish event" do
          expect(Tackle).to receive(:publish).and_call_original
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_async)

          post_payload(payload)
        end

        it "doesn't record the hook" do
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload(payload)

          expect(response).to be_ok
        end
      end

      context "when membership user added to team" do
        let(:event) { "membership" }
        let(:installation_target_type) { "integration" }
        let(:payload) { RepoHost::Github::Responses::Payload.github_app_membership_user_added_to_team }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => 13675798)
          repository = FactoryBot.create(:repository, :name => "guard", :owner => "renderedtext",
                                                      :integration_type => "github_app")
          FactoryBot.create(:project, :repository => repository)
        end

        it "doesn't required authenticated_user" do
          expect(controller).not_to receive(:authenticate_user!)

          post_app_payload(payload)
        end

        it "publish event" do
          expect(Tackle).to receive(:publish).and_call_original
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_async)

          post_payload(payload)
        end

        it "doesn't record the hook" do
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload(payload)

          expect(response).to be_ok
        end
      end

      context "when membership user removed from team" do
        let(:event) { "membership" }
        let(:installation_target_type) { "integration" }
        let(:payload) { RepoHost::Github::Responses::Payload.github_app_membership_user_removed_from_team }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => 13675798)
          repository = FactoryBot.create(:repository, :name => "guard", :owner => "renderedtext",
                                                      :integration_type => "github_app")
          FactoryBot.create(:project, :repository => repository)
        end

        it "doesn't required authenticated_user" do
          expect(controller).not_to receive(:authenticate_user!)

          post_app_payload(payload)
        end

        it "publish event" do
          expect(Tackle).to receive(:publish).and_call_original
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_async)

          post_payload(payload)
        end

        it "doesn't record the hook" do
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload(payload)

          expect(response).to be_ok
        end
      end

      context "when ping event occurs" do
        let(:event) { "ping" }

        it "doesn't publish event" do
          expect(Tackle).not_to receive(:publish)
          expect(Semaphore::GithubApp::Collaborators::Worker).not_to receive(:perform_async)

          post_payload("123")
        end

        it "doesn't record the hook" do
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload("123")

          expect(response).to be_ok
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_payload("123")
        end

        it "increments the unsupported_webhook count" do
          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.unsupported_webhook").and_call_original

          post_payload("123")
        end
      end

      context "when gollum event occurs" do
        let(:event) { "gollum" }

        it "doesn't publish event" do
          expect(Tackle).not_to receive(:publish)
          expect(Semaphore::GithubApp::Collaborators::Worker).not_to receive(:perform_async)

          post_payload("123")
        end

        it "doesn't record the hook" do
          expect(Semaphore::RepoHost::Hooks::Recorder).not_to receive(:record_hook)

          post_payload("123")

          expect(response).to be_ok
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_payload("123")
        end

        it "increments the unsupported_webhook count" do
          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.unsupported_webhook").and_call_original

          post_payload("123")
        end
      end

      context "when bad request events occur" do
        let(:event) { "push" }

        before do
          allow_any_instance_of(Semaphore::RepoHost::Github::WebhookFilter).to receive(:unavailable_payload?).and_return(true)
        end

        it "doesn't publish event" do
          expect(Tackle).not_to receive(:publish)
          expect(Semaphore::GithubApp::Collaborators::Worker).not_to receive(:perform_async)

          post_payload("")
        end

        it "saves workflow's result as BAD request" do
          expect(workflow).to receive(:update_attribute).with(:result, Workflow::RESULT_BAD_REQUEST)

          post_payload("")
        end

        it "measures the execution duration" do
          expect(Watchman).to receive(:benchmark).with("repo_host_post_commit_hooks.controller.duration").and_call_original

          post_payload("")
        end

        it "increments the no_payload count" do
          expect(Watchman).to receive(:increment).with("repo_host_post_commit_hooks.controller.no_payload").and_call_original

          post_payload("")
        end
      end
    end
  end
end
