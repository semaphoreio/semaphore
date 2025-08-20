Semaphore::Application.routes.draw do
  post "/github" => "projects#repo_host_post_commit_hook"

  # liveness and readiness probe
  get "/is_alive" => "pages#alive?"
end
