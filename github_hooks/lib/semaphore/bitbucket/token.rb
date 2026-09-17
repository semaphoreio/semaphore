module Semaphore::Bitbucket
  class Token
    def self.validation_state(token)
      return :invalid unless token.present?

      response =
        Excon.get(
          "https://api.bitbucket.org/2.0/user/workspaces?pagelen=1",
          :headers => { "Authorization" => "Bearer #{token}" }
        )

      case response.status
      when 200..299
        :valid
      when 401, 403
        :invalid
      else
        :transient
      end
    rescue Excon::Error
      :transient
    end

    def self.valid?(token)
      validation_state(token) == :valid
    end

    def self.user_token(repo_host_account)
      cache_key = cache_key(repo_host_account)

      value = Rails.cache.read(cache_key)
      if invalid_value?(value)
        value = fetch_token(repo_host_account)
        Rails.cache.write(cache_key, value) unless invalid_value?(value)
      end

      value
    end

    # PRIVATE

    def self.fetch_token(repo_host_account)
      body_params = {
          :grant_type => 'refresh_token',
          :refresh_token => repo_host_account.refresh_token
      }
      response =
        Excon.post('https://bitbucket.org/site/oauth2/access_token',
                   :user => Semaphore::Bitbucket::Credentials.app_id,
                   :password => Semaphore::Bitbucket::Credentials.secret_id,
                   :body => URI.encode_www_form(body_params),
                   :headers => { "Content-Type" => "application/x-www-form-urlencoded" })
      body =
        begin
          JSON.parse(response.body)
        rescue JSON::ParserError
          {}
        end

      if response.status <= 299
        [body["access_token"], body["expires_in"].seconds.since]
      elsif response.status >= 400 and response.status <= 499
        if invalid_grant?(body)
          repo_host_account.update(:revoked => true)
        else
          # A bare 4xx (e.g. an edge/WAF 403, or our client credentials
          # being rejected) is NOT a genuine grant revocation - only
          # error=invalid_grant means the user's refresh_token was
          # actually revoked. Latching :revoked on any 4xx here would
          # permanently disconnect the account over a transient failure.
          Rails.logger.warn(
            "[Semaphore::Bitbucket::Token] Non-revoking refresh failure " \
            "(HTTP #{response.status}) for repo_host_account #{repo_host_account.id}, not revoking"
          )
        end

        ["", nil]
      else
        ["", nil]
      end
    end

    def self.invalid_grant?(body)
      body.is_a?(Hash) && body["error"] == "invalid_grant"
    end

    def self.cache_key(repo_host_account)
      Digest::SHA2.hexdigest("bitbucket_token_#{repo_host_account.id}")
    end

    def self.invalid_value?(value)
      Array(value).compact.select(&:present?).empty? || (value[1].to_time - 5.minutes).past?
    end
  end
end
