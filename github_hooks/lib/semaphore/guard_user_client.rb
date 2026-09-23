module Semaphore
  # guard owns the OAuth lifecycle for Bitbucket and GitLab: it stores the
  # tokens, performs the refresh and maintains `revoked`. Those refresh tokens
  # are single-use and rotating, so nothing else may refresh one, and a stored
  # credential may already be past its expiry. Always ask guard.
  module GuardUserClient
    # Fits under front's 30s CheckToken timeout, leaving guard room to refresh.
    TIMEOUT = 15

    INTEGRATION_TYPES = {
      "bitbucket" => :BITBUCKET,
      "gitlab" => :GITLAB
    }.freeze

    module_function

    def owns?(integration_type)
      INTEGRATION_TYPES.key?(integration_type)
    end

    # Returns [token, expires_at]. Raises GRPC::BadStatus when guard has no
    # usable credential, so callers decide what that means for them.
    def repository_token(user_id, integration_type)
      request = InternalApi::User::GetRepositoryTokenRequest.new(
        :user_id => user_id,
        :integration_type => INTEGRATION_TYPES.fetch(integration_type)
      )

      response = stub.get_repository_token(request, :deadline => Time.now.utc + TIMEOUT)

      [response.token, to_time(response.expires_at)]
    end

    def stub
      InternalApi::User::UserService::Stub.new(App.user_api_url, :this_channel_is_insecure)
    end

    def to_time(timestamp)
      Time.at(timestamp.seconds) if timestamp
    end
  end
end
