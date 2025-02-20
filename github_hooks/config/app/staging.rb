require "semaphore_config"

App.configure do
  config.host = SemaphoreConfig.host
  config.hooks_url = config.base_url
  config.base_url = "https://#{config.host}"

  config.github_app_id = SemaphoreConfig.github_app_id
  config.github_secret_id = SemaphoreConfig.github_secret_id

  config.bitbucket_app_id = SemaphoreConfig.bitbucket_app_id
  config.bitbucket_secret_id = SemaphoreConfig.bitbucket_secret_id
  config.bitbucket_login = true
end
