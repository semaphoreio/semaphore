module Semaphore::RepoHost::Hooks
  class Request
    attr_accessor :raw_request

    def self.normalize_params(params)
      return params if params[:payload].present?

      new_params = ActionController::Parameters.new

      new_params["hash_id"] = params["hash_id"]
      new_params["payload"] = params.except("hash_id", "controller", "action").to_json

      new_params
    end

    def initialize(request)
      @raw_request = request
      @user_agent = request.headers["User-Agent"]
      @delivery_id = request.headers["X-GitHub-Delivery"]
      @repo_host = extract_repo_host(request)
      @event = request.headers["X-GitHub-Event"]
    end

    def github?
      @repo_host == Repository::GITHUB_PROVIDER
    end

    def bitbucket_v1?
      @user_agent == "Bitbucket.org"
    end

    def bitbucket_v2?
      @user_agent == "Bitbucket-Webhooks/2.0"
    end

    def semaphore?
      @user_agent == "Semaphore-Webhooks"
    end

    attr_reader :delivery_id, :event

    private

    def extract_repo_host(request)
      if @user_agent.include?("GitHub")
        Repository::GITHUB_PROVIDER
      elsif @user_agent.include?("Bitbucket")
        Repository::BITBUCKET_PROVIDER
      end
    end
  end
end
