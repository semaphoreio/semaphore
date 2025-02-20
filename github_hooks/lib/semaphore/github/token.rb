module Semaphore::Github
  class Token
    attr_reader :token

    def initialize(token)
      @token = token
      @authorize_path = "https://#{App.github_app_id}:#{App.github_secret_id}@api.github.com/applications/#{App.github_app_id}/tokens/#{@token}"
    end

    def authorized?
      make_authorized_request
      token_authorized?
    end

    def reauthorize
      find_user_and_account
      make_reauthorize_request
      return unless token_authorized?
      assign_new_token_to_user
    end

    private

    def make_authorized_request
      @response = connection.get
    end

    def make_reauthorize_request
      @response = connection.post
    end

    def connection
      Faraday::Connection.new(@authorize_path)
    end

    def token_authorized?
      body = JSON.parse(@response.body)

      if body["message"] == "Not Found"
        false
      else
        true
      end
    end

    def find_user_and_account
      @account = RepoHostAccount.github.find_by_token(@token)
      @user = @account.user
    end

    def assign_new_token_to_user
      new_token = JSON.parse(@response.body)["token"]

      @token = new_token
      @account.update_attribute(:token, new_token)
    end
  end
end
