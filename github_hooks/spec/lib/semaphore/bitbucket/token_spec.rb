require "spec_helper"

RSpec.describe Semaphore::Bitbucket::Token do
  describe ".validation_state" do
    it "returns :invalid when token is blank" do
      expect(described_class.validation_state(nil)).to eq(:invalid)
      expect(described_class.validation_state("")).to eq(:invalid)
    end

    it "returns :valid for 2xx response" do
      allow(Excon).to receive(:get).and_return(instance_double(Excon::Response, :status => 200))

      expect(described_class.validation_state("token")).to eq(:valid)
    end

    it "returns :invalid for 401/403 response" do
      allow(Excon).to receive(:get).and_return(instance_double(Excon::Response, :status => 401))
      expect(described_class.validation_state("token")).to eq(:invalid)

      allow(Excon).to receive(:get).and_return(instance_double(Excon::Response, :status => 403))
      expect(described_class.validation_state("token")).to eq(:invalid)
    end

    it "returns :transient for non-auth failures" do
      allow(Excon).to receive(:get).and_return(instance_double(Excon::Response, :status => 429))
      expect(described_class.validation_state("token")).to eq(:transient)

      allow(Excon).to receive(:get).and_return(instance_double(Excon::Response, :status => 503))
      expect(described_class.validation_state("token")).to eq(:transient)
    end

    it "returns :transient when request raises Excon::Error" do
      allow(Excon).to receive(:get).and_raise(Excon::Error.new("boom"))

      expect(described_class.validation_state("token")).to eq(:transient)
    end
  end

  describe ".valid?" do
    it "returns true only for :valid validation state" do
      allow(described_class).to receive(:validation_state).with("token").and_return(:valid)
      expect(described_class.valid?("token")).to be(true)

      allow(described_class).to receive(:validation_state).with("token").and_return(:invalid)
      expect(described_class.valid?("token")).to be(false)

      allow(described_class).to receive(:validation_state).with("token").and_return(:transient)
      expect(described_class.valid?("token")).to be(false)
    end
  end
end
