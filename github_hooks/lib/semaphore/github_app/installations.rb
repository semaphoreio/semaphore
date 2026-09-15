class Semaphore::GithubApp::Installations
  def self.init
    if Semaphore::GithubApp::Credentials.github_application_id.present? &&
       GithubAppInstallation.count.zero?
      init!
    end
  end

  def self.init!
    token = Semaphore::GithubApp::Token.generate_jwt

    response = Excon.get(
      "https://api.github.com/app/installations",
      :headers => {
        "User-Agent" => "Awesome-Octocat-App",
        "Authorization" => "Bearer #{token}",
        "Accept" => "application/vnd.github.v3+json"
      }
    )

    if response.status < 300
      body = JSON.parse(response.data[:body])
      body.map do |data|
        GithubAppInstallation.create(:installation_id => data["id"].to_i)
        begin
          Semaphore::GithubApp::Repositories.refresh(data["id"].to_i)
        rescue Semaphore::GithubApp::LowRateLimitError => e
          # Skip a throttled installation so it doesn't abort init for the rest;
          # its repositories populate on the next webhook or a manual refresh.
          Rails.logger.warn("[Semaphore::GithubApp::Installation] Skipping refresh for installation #{data["id"]} — #{e.message}")
        end
      end
    else
      Rails.logger.error("[Semaphore::GithubApp::Installation] Failed to fetch installations")

      nil
    end
  end
end
