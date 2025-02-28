App.configure do
  config.base_url = "http://localhost"
  config.hooks_url = "http://localhost"

  config.github_application_url = "https://github.com/apps/semaphoreci-test"
  config.github_application_id = 90709
  config.github_bot_name = "semaphoreci-test[bot]"
  config.github_application_key_path = "github_app.pem"

  config.github_app_id = "bd59c3a0c448179b5f3f"
  config.github_secret_id = "c40e646d16dca15d4a5155397e4e66b928678f15"
  config.github_app_webhook_secret = "lkasjdlkjKSJHKsa123lskdfn"
  config.check_github_app_webhook = true

  config.bitbucket_app_id = "G3cXBDsDEwVp25rCXL"
  config.bitbucket_secret_id = "LNNfhaLKsfuzjYEeJLkN5Y93cNDb2ej4"
  config.bitbucket_login = true

  config.gitlab_app_id = ""
  config.gitlab_secret_id = ""
  config.gitlab_login = true
end
