require "spec_helper"
require "active_support/testing/time_helpers"

RSpec.describe LicenseVerifier do
  include ActiveSupport::Testing::TimeHelpers

  before do
    LicenseVerifier.instance_variable_set(:@singleton__instance__, nil)
  end

  describe ".verify" do
    let(:stub_instance) { instance_double(InternalApi::License::LicenseService::Stub) }
    let(:valid_response) { InternalApi::License::VerifyLicenseResponse.new(valid: true) }
    let(:invalid_response) { InternalApi::License::VerifyLicenseResponse.new(valid: false) }
    let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

    before do
      allow(App).to receive(:license_checker_url).and_return("license-checker:50051")
      allow(InternalApi::License::LicenseService::Stub).to receive(:new).and_return(stub_instance)
      allow(InternalApi::License::VerifyLicenseRequest).to receive(:new).and_return(instance_double(InternalApi::License::VerifyLicenseRequest))

      instance = LicenseVerifier.instance
      instance.instance_variable_set(:@cache, memory_cache)
    end

    context "when license is valid" do
      before do
        allow(stub_instance).to receive(:verify_license).and_return(valid_response)
      end

      it "returns true" do
        expect(LicenseVerifier.verify).to be(true)
      end

      it "caches the result" do
        cache = LicenseVerifier.instance.instance_variable_get(:@cache)
        expect(cache).to receive(:fetch).with(
          LicenseVerifier::CACHE_KEY,
          expires_in: LicenseVerifier::CACHE_TTL,
          race_condition_ttl: 2.minutes
        ).and_call_original

        LicenseVerifier.verify
      end
    end

    context "when license is invalid" do
      before do
        allow(stub_instance).to receive(:verify_license).and_return(invalid_response)
      end

      it "returns false" do
        expect(LicenseVerifier.verify).to be(false)
      end
    end

    context "when gRPC raises an error" do
      before do
        allow(stub_instance).to receive(:verify_license).and_raise(GRPC::BadStatus.new(1, "Error"))
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error and returns false" do
        expect(Rails.logger).to receive(:error).with(/License check error/)
        expect(LicenseVerifier.verify).to be(false)
      end
    end

    context "when other errors occur" do
      before do
        allow(stub_instance).to receive(:verify_license).and_raise(StandardError.new("Unknown error"))
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error and returns false" do
        expect(Rails.logger).to receive(:error).with(/License check error: Unknown error/)
        expect(LicenseVerifier.verify).to be(false)
      end
    end
  end

  describe "singleton behavior" do
    it "returns the same instance when called multiple times" do
      instance1 = LicenseVerifier.instance
      instance2 = LicenseVerifier.instance

      expect(instance1).to be(instance2)
    end
  end

  describe "caching behavior" do
    let(:stub_instance) { instance_double(InternalApi::License::LicenseService::Stub) }
    let(:valid_response) { InternalApi::License::VerifyLicenseResponse.new(valid: true) }
    let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

    before do
      allow(App).to receive(:license_checker_url).and_return("license-checker:50051")
      allow(InternalApi::License::LicenseService::Stub).to receive(:new).and_return(stub_instance)
      allow(InternalApi::License::VerifyLicenseRequest).to receive(:new).and_return(instance_double(InternalApi::License::VerifyLicenseRequest))

      instance = LicenseVerifier.instance
      instance.instance_variable_set(:@cache, memory_cache)

      allow(stub_instance).to receive(:verify_license).and_return(valid_response)
    end

    it "only calls the license service once when called multiple times" do
      expect(stub_instance).to receive(:verify_license).once.and_return(valid_response)

      LicenseVerifier.verify

      LicenseVerifier.verify
    end

    it "respects the cache TTL" do
      expect(stub_instance).to receive(:verify_license).twice.and_return(valid_response)

      LicenseVerifier.verify

      travel_to(Time.now + LicenseVerifier::CACHE_TTL + 1.second) do
        LicenseVerifier.verify
      end
    end

    it "stores the result in the cache with the correct key" do
      LicenseVerifier.verify

      expect(memory_cache.exist?(LicenseVerifier::CACHE_KEY)).to be true
    end
  end
end
