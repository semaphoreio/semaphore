# Configuration based on Heroku's docs for deploying Puma based Rails apps.
# https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server

workers Integer(ENV["WEB_CONCURRENCY"] || 2)
threads_count = Integer(ENV["RAILS_MAX_THREADS"] || 5)
threads threads_count, threads_count

preload_app!

port        ENV["PORT"] || 3000
environment ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"

on_worker_boot do
  # Worker specific setup for Rails 4.1+
  # See: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#on-worker-boot
  ActiveRecord::Base.establish_connection
end
