require "semaphore_config"

App.configure do
  config.base_url = SemaphoreConfig.base_url
  config.hooks_url = config.base_url

  config.github_application_url = "https://github.com/apps/semaphoreci-test"
  config.github_application_id = 90709
  config.github_bot_name = "semaphoreci-test[bot]"
  config.github_application_key_path = "github_app.pem"

  config.github_app_id = SemaphoreConfig.github_app_id
  config.github_secret_id = SemaphoreConfig.github_secret_id
  config.github_app_webhook_secret = SemaphoreConfig.github_app_webhook_secret
  config.check_github_app_webhook = SemaphoreConfig.check_github_app_webhook

  config.bitbucket_app_id = SemaphoreConfig.bitbucket_app_id
  config.bitbucket_secret_id = SemaphoreConfig.bitbucket_secret_id
  config.bitbucket_login = true

  config.gitlab_app_id = SemaphoreConfig.gitlab_app_id
  config.gitlab_secret_id = SemaphoreConfig.gitlab_secret_id
  config.gitlab_login = true
end
