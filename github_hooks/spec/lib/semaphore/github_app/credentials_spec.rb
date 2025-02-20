require "spec_helper"

RSpec.describe Semaphore::GithubApp::Credentials do
  before do
    Semaphore::GithubApp::Credentials.instance_variable_set(:@private_key, nil)
    Semaphore::GithubApp::Credentials.instance_variable_set(:@github_application_url, nil)
    Semaphore::GithubApp::Credentials.instance_variable_set(:@github_application_id, nil)
  end

  context "when the local file exists" do
    before do
      allow(File).to receive(:exist?).with(App.github_application_key_path).and_return(true)
      allow(Semaphore::GithubApp::Credentials::Local).to receive(:pem).and_return("local_pem_value")
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:pem).and_return(nil)
    end

    it "returns the value from the local file and caches it" do
      expect(Semaphore::GithubApp::Credentials.private_key).to eq("local_pem_value")
      expect(Semaphore::GithubApp::Credentials.private_key).to eq("local_pem_value")
      expect(Semaphore::GithubApp::Credentials::Local).to have_received(:pem).once
    end
  end

  context "when the local file does not exist" do
    before do
      allow(File).to receive(:exist?).with(App.github_application_key_path).and_return(false)
      allow(Semaphore::GithubApp::Credentials::Local).to receive(:pem).and_return(nil)
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:pem).and_return("instance_pem_value")
    end

    it "falls back to InstanceConfigClient and caches the value" do
      expect(Semaphore::GithubApp::Credentials.private_key).to eq("instance_pem_value")
      expect(Semaphore::GithubApp::Credentials.private_key).to eq("instance_pem_value")
      expect(Semaphore::GithubApp::Credentials::InstanceConfigClient).to have_received(:pem).once
    end
  end

  context "when both the local file and InstanceConfigClient fail" do
    before do
      allow(File).to receive(:exist?).with(App.github_application_key_path).and_return(false)
      allow(Semaphore::GithubApp::Credentials::Local).to receive(:pem).and_return(nil)
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:pem).and_return(nil)
    end

    it "returns nil if both fallbacks are unavailable" do
      expect(Semaphore::GithubApp::Credentials.private_key).to be_nil
    end
  end

  context "when the local URL exists" do
    before do
      allow(Semaphore::GithubApp::Credentials::Local).to receive(:github_application_url).and_return("local_url_value")
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:github_application_url).and_return(nil)
    end

    it "returns the value from the local URL and caches it" do
      expect(Semaphore::GithubApp::Credentials.github_application_url).to eq("local_url_value")
      expect(Semaphore::GithubApp::Credentials.github_application_url).to eq("local_url_value")
      expect(Semaphore::GithubApp::Credentials::Local).to have_received(:github_application_url).once
    end
  end

  context "when the local URL does not exist" do
    before do
      allow(Semaphore::GithubApp::Credentials::Local).to receive(:github_application_url).and_return(nil)
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:github_application_url).and_return("instance_url_value")
    end

    it "falls back to InstanceConfigClient and caches the value" do
      expect(Semaphore::GithubApp::Credentials.github_application_url).to eq("instance_url_value")
      expect(Semaphore::GithubApp::Credentials.github_application_url).to eq("instance_url_value")
      expect(Semaphore::GithubApp::Credentials::InstanceConfigClient).to have_received(:github_application_url).once
    end
  end

  context "when both the local URL and InstanceConfigClient fail" do
    before do
      allow(Semaphore::GithubApp::Credentials::Local).to receive(:github_application_url).and_return(nil)
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:github_application_url).and_return(nil)
    end

    it "returns nil if both fallbacks are unavailable" do
      expect(Semaphore::GithubApp::Credentials.github_application_url).to be_nil
    end
  end

  context "when the local ID exists" do
    before do
      allow(Semaphore::GithubApp::Credentials::Local).to receive(:github_application_id).and_return("local_id_value")
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:github_application_id).and_return(nil)
    end

    it "returns the value from the local ID and caches it" do
      expect(Semaphore::GithubApp::Credentials.github_application_id).to eq("local_id_value")
      expect(Semaphore::GithubApp::Credentials.github_application_id).to eq("local_id_value")
      expect(Semaphore::GithubApp::Credentials::Local).to have_received(:github_application_id).once
    end
  end

  context "when the local ID does not exist" do
    before do
      allow(Semaphore::GithubApp::Credentials::Local).to receive(:github_application_id).and_return(nil)
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:github_application_id).and_return("instance_id_value")
    end

    it "falls back to InstanceConfigClient and caches the value" do
      expect(Semaphore::GithubApp::Credentials.github_application_id).to eq("instance_id_value")
      expect(Semaphore::GithubApp::Credentials.github_application_id).to eq("instance_id_value")
      expect(Semaphore::GithubApp::Credentials::InstanceConfigClient).to have_received(:github_application_id).once
    end
  end

  context "when both the local ID and InstanceConfigClient fail" do
    before do
      allow(Semaphore::GithubApp::Credentials::Local).to receive(:github_application_id).and_return(nil)
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:github_application_id).and_return(nil)
    end

    it "returns nil if both fallbacks are unavailable" do
      expect(Semaphore::GithubApp::Credentials.github_application_id).to be_nil
    end
  end
end
