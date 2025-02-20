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
        GithubAppInstallation.create(:installation_id => data["id"].to_i, :repositories => [])
        Semaphore::GithubApp::Repositories.refresh(data["id"].to_i)
      end
    else
      Rails.logger.error("[Semaphore::GithubApp::Installation] Failed to fetch installations")

      nil
    end
  end
end
