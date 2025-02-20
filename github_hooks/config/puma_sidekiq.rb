# Configuration based on Heroku's docs for deploying Puma based Rails apps.
# https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server

workers Integer(ENV["WEB_CONCURRENCY"] || 1)
threads_count = Integer(ENV["MAX_THREADS"] || 2)
threads threads_count, threads_count

preload_app!

port ENV["PORT"] || 3000
