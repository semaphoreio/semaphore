# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

#
# Configuration about the Semaphore organization and its root user.
#
config :e2e,
  semaphore_organization: System.fetch_env!("SEMAPHORE_ORGANIZATION"),
  semaphore_api_token: System.fetch_env!("SEMAPHORE_API_TOKEN"),
  semaphore_root_email: System.fetch_env!("SEMAPHORE_USER_EMAIL"),
  semaphore_root_password: System.fetch_env!("SEMAPHORE_USER_PASSWORD"),
  semaphore_base_domain: System.fetch_env!("SEMAPHORE_BASE_DOMAIN")

#
# Configuration about GitHub organization and repository,
# where we keep our static YAML files used for testing.
#
config :e2e,
  github_organization: System.fetch_env!("GITHUB_ORGANIZATION"),
  github_repository: System.fetch_env!("GITHUB_REPOSITORY"),
  github_branch: System.get_env("GITHUB_BRANCH") || "refs/heads/master"

config :e2e, http_timeout: 30_000

config :logger, :console,
  level: :info,
  format: "$time $metadata[$level] $message\n"

config :httpoison,
  timeout: 30_000,
  recv_timeout: 30_000

if System.get_env("START_WALLABY") do
  config :wallaby,
    screenshot_dir: System.get_env("WALLABY_SCREENSHOTS") || "./out/screenshots",
    screenshot_on_failure: true,
    driver: Wallaby.Experimental.Chrome,
    chromedriver: System.get_env("CHROMEDRIVER") || "/usr/bin/chromedriver",
    max_wait_time: 10_000,
    chrome: [
      headless: true,
      args: [
        "--no-sandbox",
        "--disable-gpu",
        "--disable-dev-shm-usage",
        "--disable-software-rasterizer",
        "--window-size=1280,800"
      ]
    ]
end

import_config "#{Mix.env()}.exs"
