require "spec_helper"

module Semaphore::RepoHost::Hooks
  RSpec.describe Request do
    describe ".normalize_params" do
      let(:params) do
        ActionController::Parameters.new(:action => "some_action",
                                         :hash_id => "some_hash_id",
                                         :controller => "some_controller",
                                         :ref => "refs/heads/master",
                                         :created => "true")
      end
      let(:properly_formatted_params) do
        ActionController::Parameters.new(:hash_id => "some_hash_id",
                                         :payload => "{\"ref\":\"refs/heads/master\",\"created\":\"true\"}")
      end

      context "payload is parameter" do
        it "sets paylod as key in params" do
          expect(Semaphore::RepoHost::Hooks::Request.normalize_params(properly_formatted_params)).to eq(properly_formatted_params)
        end
      end

      context "patload is in raw body" do
        it "sets paylod as key in params" do
          expect(Semaphore::RepoHost::Hooks::Request.normalize_params(params)).to eq(properly_formatted_params)
        end
      end
    end

    def init_request(repo_host_request)
      @request = Request.new(repo_host_request)
    end

    describe "#github?" do
      context "when request is from GitHub" do
        let(:github_user_agent) { "GitHub-Hookshot/xxx" }
        let(:repo_host_request) { double(ActionDispatch::Request, :headers => { "User-Agent" => github_user_agent }) }

        it "returns true" do
          init_request(repo_host_request)

          expect(@request.github?).to be_truthy
        end
      end

      context "when request is not from GitHub" do
        let(:repo_host_request) do
          double(ActionDispatch::Request, :headers => { "User-Agent" => "unknown_user_agent" })
        end

        it "returns false" do
          init_request(repo_host_request)

          expect(@request.github?).to be_falsey
        end
      end
    end

    describe "#bitbucket_v1?" do
      context "when request is a V1 hook from Bitbucket" do
        let(:bitbucket_user_agent) { "Bitbucket.org" }
        let(:repo_host_request) do
          double(ActionDispatch::Request, :headers => { "User-Agent" => bitbucket_user_agent })
        end

        it "returns true" do
          init_request(repo_host_request)

          expect(@request.bitbucket_v1?).to be_truthy
        end
      end

      context "when request is a V2 hook from Bitbucket" do
        let(:bitbucket_user_agent) { "Bitbucket-Webhooks/2.0" }
        let(:repo_host_request) do
          double(ActionDispatch::Request, :headers => { "User-Agent" => bitbucket_user_agent })
        end

        it "returns false" do
          init_request(repo_host_request)

          expect(@request.bitbucket_v1?).to be_falsy
        end
      end

      context "when request is not from Bitbucket" do
        let(:repo_host_request) do
          double(ActionDispatch::Request, :headers => { "User-Agent" => "unknown_user_agent" })
        end

        it "returns false" do
          init_request(repo_host_request)

          expect(@request.bitbucket_v1?).to be_falsey
        end
      end
    end

    describe "#bitbucket_v2?" do
      context "when request is a V2 hook from Bitbucket" do
        let(:bitbucket_user_agent) { "Bitbucket-Webhooks/2.0" }
        let(:repo_host_request) do
          double(ActionDispatch::Request, :headers => { "User-Agent" => bitbucket_user_agent })
        end

        it "returns true" do
          init_request(repo_host_request)

          expect(@request.bitbucket_v2?).to be_truthy
        end
      end

      context "when request is a V1 hook from Bitbucket" do
        let(:bitbucket_user_agent) { "Bitbucket.org" }
        let(:repo_host_request) do
          double(ActionDispatch::Request, :headers => { "User-Agent" => bitbucket_user_agent })
        end

        it "returns false" do
          init_request(repo_host_request)

          expect(@request.bitbucket_v2?).to be_falsy
        end
      end

      context "when request is not from Bitbucket" do
        let(:repo_host_request) do
          double(ActionDispatch::Request, :headers => { "User-Agent" => "unknown_user_agent" })
        end

        it "returns false" do
          init_request(repo_host_request)

          expect(@request.bitbucket_v2?).to be_falsey
        end
      end
    end

    describe "#semaphore?" do
      context "when request is a Semaphore webhook" do
        let(:semaphore_user_agent) { "Semaphore-Webhooks" }
        let(:repo_host_request) do
          double(ActionDispatch::Request, :headers => { "User-Agent" => semaphore_user_agent })
        end

        it "returns true" do
          init_request(repo_host_request)

          expect(@request.semaphore?).to be_truthy
        end
      end

      context "when request is not from Semaphore" do
        let(:repo_host_request) do
          double(ActionDispatch::Request, :headers => { "User-Agent" => "unknown_user_agent" })
        end

        it "returns false" do
          init_request(repo_host_request)

          expect(@request.semaphore?).to be_falsey
        end
      end
    end

    describe "#delivery_id" do
      context "when request has delivery header" do
        let(:delivery_id) { "Semaphore-Webhooks" }
        let(:repo_host_request) do
          double(ActionDispatch::Request, :headers => { "User-Agent" => "", "X-GitHub-Delivery" => delivery_id })
        end

        it "returns true" do
          init_request(repo_host_request)

          expect(@request.delivery_id).to eq(delivery_id)
        end
      end

      context "when request do not have delivery header" do
        let(:repo_host_request) { double(ActionDispatch::Request, :headers => { "User-Agent" => "" }) }

        it "returns false" do
          init_request(repo_host_request)

          expect(@request.delivery_id).to be_nil
        end
      end
    end

    describe "#event" do
      context "when request has event header" do
        let(:event) { "Semaphore-Webhooks" }
        let(:repo_host_request) do
          double(ActionDispatch::Request, :headers => { "User-Agent" => "", "X-GitHub-Event" => event })
        end

        it "returns true" do
          init_request(repo_host_request)

          expect(@request.event).to eq(event)
        end
      end

      context "when request do not have delivery header" do
        let(:repo_host_request) { double(ActionDispatch::Request, :headers => { "User-Agent" => "" }) }

        it "returns false" do
          init_request(repo_host_request)

          expect(@request.event).to be_nil
        end
      end
    end
  end
end
