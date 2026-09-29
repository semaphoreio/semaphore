module GithubAppInstallationHelpers
  def repositories_from_table(installation)
    installation.installation_repositories.order(:created_at, :id).map do |repository|
      { "id" => repository.remote_id, "slug" => repository.slug }
    end
  end
end

RSpec.configure do |config|
  config.include GithubAppInstallationHelpers
end
