require "spec_helper"

RSpec.describe "Githubhooks", :type => :request do

  describe "POST /github" do

    before do
      @project = FactoryBot.create(:project)
    end

    def post_github_hook(event)
      path = github_path(:hash_id => @project.id, :payload => @payload)
      url = "http://hooks.example.com/#{path}"

      post url, :headers => { "X-Github-Event" => event, "User-Agent" => "GitHub" }
    end

    context "with project hash_id and payload" do

      it "responds with OK" do
        @payload = RepoHost::Github::Responses::Payload.post_receive_hook

        post_github_hook("push")

        expect(response.status).to eq(200)
      end
    end

    describe "pull request should be built" do

      context "pull request is opened" do

        before { @payload = RepoHost::Github::Responses::Payload.post_receive_hook_pull_request }

        it "builds the branch" do
          expect(Semaphore::RepoHost::Hooks::Handler::Worker).to receive(:perform_async)

          post_github_hook("pull_request")
        end

        it "responds with OK" do
          post_github_hook("pull_request")

          expect(response.status).to eq(200)
        end

      end

      context "pull request is synchronized" do

        before { @payload = RepoHost::Github::Responses::Payload.post_receive_hook_pull_request_commit }

        it "builds the branch" do
          expect(Semaphore::RepoHost::Hooks::Handler::Worker).to receive(:perform_async)

          post_github_hook("pull_request")
        end

        it "responds with OK" do
          post_github_hook("pull_request")

          expect(response.status).to eq(200)
        end

      end

      context "pull request is closed" do

        before { @payload = RepoHost::Github::Responses::Payload.post_receive_hook_pull_request_closed }

        it "builds the branch" do
          expect(Semaphore::RepoHost::Hooks::Handler::Worker).to receive(:perform_async)

          post_github_hook("pull_request")
        end

        it "responds with OK" do
          post_github_hook("pull_request")

          expect(response.status).to eq(200)
        end

      end
    end

    describe "pull request shouldn't be built" do

      context "pull request is assigned" do

        before { @payload = RepoHost::Github::Responses::Payload.pull_request_assigned }

        it "doesn't build the branch" do
          expect(Semaphore::RepoHost::Hooks::Handler::Worker).not_to receive(:perform_async)

          post_github_hook("pull_request")
        end

        it "responds with OK" do
          post_github_hook("pull_request")

          expect(response.status).to eq(200)
        end

      end

      context "pull request is labeled" do

        before { @payload = RepoHost::Github::Responses::Payload.pull_request_labeled }

        it "doesn't build the branch" do
          expect(Semaphore::RepoHost::Hooks::Handler::Worker).not_to receive(:perform_async)

          post_github_hook("pull_request")
        end

        it "responds with OK" do
          post_github_hook("pull_request")

          expect(response.status).to eq(200)
        end

      end

    end

    context "payload with asian characters" do

      it "responds with OK" do
        @payload = RepoHost::Github::Responses::Payload.asian_post_receive_hook.super_encode_to_utf8

        post_github_hook("push")

        expect(response.status).to be(200)
      end
    end

  end

end
