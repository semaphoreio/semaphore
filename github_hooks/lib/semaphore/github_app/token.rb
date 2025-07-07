require "openssl"
require "jwt"

class Semaphore::GithubApp::Token
  def self.organization_token(organisation_name)
    installation = GithubAppInstallation.find_for_organization!(organisation_name)

    installation_token(installation.installation_id)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("[Semaphore::GithubApp::Token] GithubAppInstallation not found for organization: #{organisation_name}")

    nil
  end

  def self.repository_token(repository_slug)
    installation = GithubAppInstallation.find_for_repository!(repository_slug)

    installation_token(installation.installation_id)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("[Semaphore::GithubApp::Token] GithubAppInstallation not found for repository: #{repository_slug}")

    nil
  end

  def self.installation_token(installation_id)
    cache_key = cache_key(installation_id)

    value = Rails.cache.read(cache_key)
    if invalid_value?(value)
      value = fetch_token(installation_id)
      Rails.cache.write(cache_key, value) unless invalid_value?(value)
    end

    Rails.logger.error("[Semaphore::GithubApp::Token] Failed to fetch token for installation_id: #{installation_id}") if invalid_value?(value)

    value
  end

  # PRIVATE

  def self.fetch_token(installation_id)
    response = Excon.post(
      "https://api.github.com/app/installations/#{installation_id}/access_tokens",
      :headers => {
        "User-Agent" => "Awesome-Octocat-App",
        "Authorization" => "Bearer #{generate_jwt}",
        "Accept" => "application/vnd.github.v3+json"
      })

    if response.status < 300
      body = JSON.parse(response.data[:body])

      [body["token"], body["expires_at"]]
    else
      Rails.logger.error("[Semaphore::GithubApp::Token] Failed to fetch token for installation_id: #{installation_id}, response: #{response.status} - #{response.body}")

      nil
    end
  end

  def self.generate_jwt
    payload = {
      :iat => Time.now.to_i,
      :exp => Time.now.to_i + (10 * 60),
      :iss => Semaphore::GithubApp::Credentials.github_application_id
    }

    JWT.encode(payload, private_key, "RS256")
  end

  def self.private_key
    private_pem = Semaphore::GithubApp::Credentials.private_key
    OpenSSL::PKey::RSA.new(private_pem)
  end

  def self.cache_key(installation_id)
    installation_id
  end

  def self.invalid_value?(value)
    Array(value).compact.select(&:present?).empty? || (value[1].to_time - 5.minutes).past?
  end
end
