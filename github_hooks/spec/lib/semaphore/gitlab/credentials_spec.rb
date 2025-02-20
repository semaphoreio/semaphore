require "spec_helper"

RSpec.describe Semaphore::Gitlab::Credentials do
  before do
    Semaphore::Gitlab::Credentials.instance_variable_set(:@app_id, nil)
    Semaphore::Gitlab::Credentials.instance_variable_set(:@secret_id, nil)
  end

  context "when the local app_id exists" do
    before do
      allow(Semaphore::Gitlab::Credentials::Local).to receive(:app_id).and_return("local_app_id")
      allow(Semaphore::Gitlab::Credentials::InstanceConfigClient).to receive(:app_id).and_return(nil)
    end

    it "returns the value from local and caches it" do
      expect(Semaphore::Gitlab::Credentials.app_id).to eq("local_app_id")
      expect(Semaphore::Gitlab::Credentials.app_id).to eq("local_app_id")
      expect(Semaphore::Gitlab::Credentials::Local).to have_received(:app_id).once
    end
  end

  context "when the local app_id does not exist" do
    before do
      allow(Semaphore::Gitlab::Credentials::Local).to receive(:app_id).and_return(nil)
      allow(Semaphore::Gitlab::Credentials::InstanceConfigClient).to receive(:app_id).and_return("instance_app_id")
    end

    it "falls back to InstanceConfigClient and caches the value" do
      expect(Semaphore::Gitlab::Credentials.app_id).to eq("instance_app_id")
      expect(Semaphore::Gitlab::Credentials.app_id).to eq("instance_app_id")
      expect(Semaphore::Gitlab::Credentials::InstanceConfigClient).to have_received(:app_id).once
    end
  end

  context "when both the local app_id and InstanceConfigClient fail" do
    before do
      allow(Semaphore::Gitlab::Credentials::Local).to receive(:app_id).and_return(nil)
      allow(Semaphore::Gitlab::Credentials::InstanceConfigClient).to receive(:app_id).and_return(nil)
    end

    it "returns nil if both fallbacks are unavailable" do
      expect(Semaphore::Gitlab::Credentials.app_id).to be_nil
    end
  end

  context "when the local secret_id exists" do
    before do
      allow(Semaphore::Gitlab::Credentials::Local).to receive(:secret_id).and_return("local_secret")
      allow(Semaphore::Gitlab::Credentials::InstanceConfigClient).to receive(:secret_id).and_return(nil)
    end

    it "returns the value from local and caches it" do
      expect(Semaphore::Gitlab::Credentials.secret_id).to eq("local_secret")
      expect(Semaphore::Gitlab::Credentials.secret_id).to eq("local_secret")
      expect(Semaphore::Gitlab::Credentials::Local).to have_received(:secret_id).once
    end
  end

  context "when the local secret_id does not exist" do
    before do
      allow(Semaphore::Gitlab::Credentials::Local).to receive(:secret_id).and_return(nil)
      allow(Semaphore::Gitlab::Credentials::InstanceConfigClient).to receive(:secret_id).and_return("instance_secret")
    end

    it "falls back to InstanceConfigClient and caches the value" do
      expect(Semaphore::Gitlab::Credentials.secret_id).to eq("instance_secret")
      expect(Semaphore::Gitlab::Credentials.secret_id).to eq("instance_secret")
      expect(Semaphore::Gitlab::Credentials::InstanceConfigClient).to have_received(:secret_id).once
    end
  end

  context "when both the local secret_id and InstanceConfigClient fail" do
    before do
      allow(Semaphore::Gitlab::Credentials::Local).to receive(:secret_id).and_return(nil)
      allow(Semaphore::Gitlab::Credentials::InstanceConfigClient).to receive(:secret_id).and_return(nil)
    end

    it "returns nil if both fallbacks are unavailable" do
      expect(Semaphore::Gitlab::Credentials.secret_id).to be_nil
    end
  end
end
