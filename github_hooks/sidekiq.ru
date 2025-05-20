require 'sidekiq'

Sidekiq.configure_client do |config|
  config.redis = { :url => ENV["REDIS_SIDEKIQ_URL"], :id => nil, :password => ENV["REDIS_SIDEKIQ_PASSWORD"] }
end

# first, use IRB to create a shared secret key for sessions and commit it
require 'securerandom'; File.open(".session.key", "w") {|f| f.write(SecureRandom.hex(32)) }

# now use the secret with a session cookie middleware
use Rack::Session::Cookie, secret: File.read(".session.key"), same_site: true, max_age: 86400

require 'sidekiq/web'
require 'sidekiq-scheduler/web'

Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  user == (ENV["SIDEKIQ_USER"] || "admin") && password == (ENV["SIDEKIQ_PASSWORD"] || "admin")
end

run Sidekiq::Web
