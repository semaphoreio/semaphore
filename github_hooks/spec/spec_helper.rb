ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__)

require "rspec/rails"
require "rspec/its"
require "rspec/benchmark"
require "webmock/rspec"
require "sidekiq/testing"

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# Silence the loggers
module Tackle
  module_function

  def publish(message, options = {})
    url         = options.fetch(:url)
    exchange    = options.fetch(:exchange)
    routing_key = options.fetch(:routing_key)
    logger      = Logger.new("/dev/null")
    connection  = options.fetch(:connection, nil)

    Tackle::Publisher.new(url, exchange, routing_key, logger, connection).publish(message)
  end
end

unless ENV["KEEP_LOGMAN"] == "true"
  class Logman
    def initialize(_options = {})
      @logger = Logger.new("/dev/null")

      if @logger.instance_of?(Logman)
        # copy constructor

        @fields = @logger.fields.dup
        @logger = @logger.logger
      else
        @fields = {}
      end

      @logger.formatter = formatter
    end
  end
end

VCR.configure do |c|
  c.cassette_library_dir = "fixtures/cassette_library"
  c.hook_into :webmock
  c.hook_into :excon
  c.ignore_localhost = true
  c.allow_http_connections_when_no_cassette = false
  c.default_cassette_options = { :record => :once }
  c.debug_logger = File.open(Rails.root.join("log/vcr.log").to_s, "w")
  c.configure_rspec_metadata!

  c.default_cassette_options = {
    :match_requests_on => [:method, VCR.request_matchers.uri_without_param(:organization_uuid)]
  }
end

begin
#  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  Rails.logger.error e.to_s.strip
  raise e
end

ActiveRecord::Base.logger = Logger.new STDOUT if ENV["VERBOSE_LOGS"]

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.raise_errors_for_deprecations!
  config.mock_with :rspec

  config.include(RSpec::Benchmark::Matchers)

  # Performance tests are best left for occasional
  # runs that do not affect TDD/BDD cycle
  if ENV["BENCHMARK"]
    config.filter_run_including :performance => true
  else
    config.filter_run_excluding :performance => true
  end

  # Extends test results with information about IO streams
  if ENV["CI"]
    config.around do |example|
      $stdout = StringIO.new
      $stderr = StringIO.new

      example.run

      example.metadata[:stdout] = $stdout.string
      example.metadata[:stderr] = $stderr.string

      $stdout = STDOUT
      $stderr = STDERR
    end
  end

  # Automatically infer an example group's spec type
  # from the file location, no longer default in RSpec 3.
  config.infer_spec_type_from_file_location!

  config.before(:all) do |_example| # rubocop:disable RSpec/BeforeAfterAll
    DatabaseCleaner.clean_with(
      :truncation,
      except: %w[ar_internal_metadata]
    )
  end

  config.before do |example|
    Rails.cache.clear if Dir.exist?("tmp/cache/")

    DatabaseCleaner[:active_record].strategy = if example.metadata[:multithreaded]
                                                 :truncation
                                               else
                                                 :transaction
                                               end

    DatabaseCleaner.start
  end

  config.after do |_example|
    # Database cleaner does support cleaning redis, but it caused some
    # unexplained flaky tests. Calling flushdb explicitly is more reliable.
    RedisClient.new(:url => App.redis_sidekiq_url).call("FLUSHDB")
    RedisClient.new(:url => App.redis_job_logs_url).call("FLUSHDB")

    DatabaseCleaner[:active_record].clean
  end
end
