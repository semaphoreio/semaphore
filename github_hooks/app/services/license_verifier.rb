# frozen_string_literal: true

require "grpc"
require "active_support"
require "active_support/cache"
require "active_support/core_ext/numeric/time"
require "singleton"

class LicenseVerifier
  include Singleton

  CACHE_KEY = "license_verification:v1"
  CACHE_TTL = 5.minutes

  # Class method to access the singleton instance's verify method
  def self.verify
    instance.verify
  end

  def initialize
    @stub = InternalApi::License::LicenseService::Stub.new(
      App.license_checker_url,
      :this_channel_is_insecure
    )
    @cache = ActiveSupport::Cache::MemoryStore.new
  end

  # Public API ---------------------------------------------------------------
  #
  # Returns the VerifyResponse protobuf or raises on failure.
  # Successful responses are cached for 5 minutes; all other results
  # bypass the cache so your next call retries the gRPC service.
  #
  def verify
    @cache.fetch(CACHE_KEY, expires_in: CACHE_TTL, race_condition_ttl: 2.minutes) do
      resp = fresh_verify!
      resp.valid # Only cache the boolean
    rescue GRPC::BadStatus, StandardError => e
      Rails.logger.error("License check error: #{e.message}")
      raise # Prevent caching of error result
    end
  rescue GRPC::BadStatus, StandardError
    false
  end

  private

  def fresh_verify!
    request = InternalApi::License::VerifyLicenseRequest.new
    @stub.verify_license(request)
  end
end
