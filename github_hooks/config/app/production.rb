require "semaphore_config"

App.configure do
  config.host = SemaphoreConfig.host

  config.base_url = "https://#{config.host}"
  config.hooks_url = "https://#{SemaphoreConfig.hooks_host}"

  config.github_application_url = SemaphoreConfig.github_application_url
  config.github_application_id = SemaphoreConfig.github_application_id
  config.github_bot_name = SemaphoreConfig.github_bot_name
  config.github_application_key_path = "private_keys/github-app-key"

  config.github_app_id = SemaphoreConfig.github_app_id
  config.github_secret_id = SemaphoreConfig.github_secret_id
  config.github_app_webhook_secret = SemaphoreConfig.github_app_webhook_secret
  config.check_github_app_webhook = SemaphoreConfig.check_github_app_webhook.to_s == "true"

  config.bitbucket_app_id = SemaphoreConfig.bitbucket_app_id
  config.bitbucket_secret_id = SemaphoreConfig.bitbucket_secret_id
  config.bitbucket_login = SemaphoreConfig.bitbucket_login.to_s == "true"

  config.gitlab_app_id = SemaphoreConfig.gitlab_app_id
  config.gitlab_secret_id = SemaphoreConfig.gitlab_secret_id
  config.gitlab_login = false
end
