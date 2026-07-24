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

  describe ".fetch_token" do
    let(:account) { FactoryBot.create(:bitbucket_account) }

    before do
      allow(Semaphore::Bitbucket::Credentials).to receive_messages(:app_id => "app-id",
                                                                   :secret_id => "secret-id")
    end

    def stub_refresh(status, body = "{}")
      allow(Excon).to receive(:post)
        .and_return(instance_double(Excon::Response, :status => status, :body => body))
    end

    it "returns the refreshed token on success" do
      stub_refresh(200, { "access_token" => "new-token", "expires_in" => 3600 }.to_json)

      token, expires_at = described_class.fetch_token(account)

      expect(token).to eq("new-token")
      expect(expires_at).to be_present
    end

    it "revokes the connection when the refresh is rejected", :aggregate_failures do
      stub_refresh(400)

      expect(described_class.fetch_token(account)).to eq(["", nil])
      expect(account.reload.revoked).to be(true)
    end

    it "does not revoke the connection when the refresh is rate limited", :aggregate_failures do
      stub_refresh(429)

      expect(described_class.fetch_token(account)).to eq(["", nil])
      expect(account.reload.revoked).to be(false)
    end

    it "does not revoke the connection when the refresh times out", :aggregate_failures do
      stub_refresh(408)

      expect(described_class.fetch_token(account)).to eq(["", nil])
      expect(account.reload.revoked).to be(false)
    end

    it "does not revoke the connection on provider-side failures", :aggregate_failures do
      stub_refresh(503)

      expect(described_class.fetch_token(account)).to eq(["", nil])
      expect(account.reload.revoked).to be(false)
    end
  end
end
