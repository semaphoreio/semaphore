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
      body = JSON.parse(response.body)

      if response.status <= 299
        [body["access_token"], body["expires_in"].seconds.since]
      elsif [408, 429].include?(response.status)
        # Transient failures must not classify the connection as revoked.
        ["", nil]
      elsif response.status >= 400 and response.status <= 499
        repo_host_account.update(:revoked => true)

        ["", nil]
      else
        ["", nil]
      end
    end

    def self.cache_key(repo_host_account)
      Digest::SHA2.hexdigest("bitbucket_token_#{repo_host_account.id}")
    end

    def self.invalid_value?(value)
      Array(value).compact.select(&:present?).empty? || (value[1].to_time - 5.minutes).past?
    end
  end
end
