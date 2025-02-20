require "spec_helper"

RSpec.describe Semaphore::GithubApp::Credentials::InstanceConfigClient do
  before do
    Semaphore::GithubApp::Credentials.instance_variable_set(:@private_key, nil)
    Semaphore::GithubApp::Credentials.instance_variable_set(:@github_application_url, nil)
    Semaphore::GithubApp::Credentials.instance_variable_set(:@github_application_id, nil)
  end

  describe ".fetch" do
    let(:client_stub) { instance_double(InternalApi::InstanceConfig::InstanceConfigService::Stub) }
    let(:mock_response) do
      InternalApi::InstanceConfig::ListConfigsResponse.new(
        configs: []
      )
    end

    before do
      allow(InternalApi::InstanceConfig::InstanceConfigService::Stub).to receive(:new).and_return(client_stub)
      allow(client_stub).to receive(:list_configs).and_return(mock_response)
    end

    it "calls list_configs on the InternalApi::InstanceConfig::InstanceConfigService::Stub" do
      result = Semaphore::GithubApp::Credentials::InstanceConfigClient.fetch

      expect(InternalApi::InstanceConfig::InstanceConfigService::Stub).to have_received(:new)
      expect(client_stub).to have_received(:list_configs)

      expect(result).to be_nil
    end

    it "logs an error when an exception is raised" do
      allow(client_stub).to receive(:list_configs).and_raise(StandardError.new("API call failed"))

      expect(Logman).to receive(:error).with(/Error while fetching config/)

      result = Semaphore::GithubApp::Credentials::InstanceConfigClient.fetch

      expect(result).to be_nil
    end
  end

  describe ".get_field" do
    let(:client_stub) { instance_double(InternalApi::InstanceConfig::InstanceConfigService::Stub) }
    let(:mock_response) do
      InternalApi::InstanceConfig::ListConfigsResponse.new(
        configs: [
          InternalApi::InstanceConfig::Config.new(
            type: InternalApi::InstanceConfig::ConfigType::CONFIG_TYPE_GITHUB_APP,
            state: InternalApi::InstanceConfig::State::STATE_CONFIGURED,
            fields: [
              InternalApi::InstanceConfig::ConfigField.new(key: "pem", value: "pem_value"),
              InternalApi::InstanceConfig::ConfigField.new(key: "html_url", value: "url_value"),
              InternalApi::InstanceConfig::ConfigField.new(key: "app_id", value: "123")
            ]
          )
        ]
      )
    end

    before do
      allow(InternalApi::InstanceConfig::InstanceConfigService::Stub).to receive(:new).and_return(client_stub)
      allow(client_stub).to receive(:list_configs).and_return(mock_response)
    end

    it "retrieves the value of the requested field" do
      pem_value = Semaphore::GithubApp::Credentials::InstanceConfigClient.get_field("pem")
      expect(pem_value).to eq("pem_value")

      url_value = Semaphore::GithubApp::Credentials::InstanceConfigClient.get_field("html_url")
      expect(url_value).to eq("url_value")

      id_value = Semaphore::GithubApp::Credentials::InstanceConfigClient.get_field("app_id")
      expect(id_value).to eq("123")
    end

    it "returns nil if the requested field is not found" do
      non_existing_field = Semaphore::GithubApp::Credentials::InstanceConfigClient.get_field("non_existing_field")
      expect(non_existing_field).to be_nil
    end

    it "returns nil if no configured config is found" do
      empty_response = InternalApi::InstanceConfig::ListConfigsResponse.new(configs: [])
      allow(client_stub).to receive(:list_configs).and_return(empty_response)

      result = Semaphore::GithubApp::Credentials::InstanceConfigClient.get_field("pem")
      expect(result).to be_nil
    end
  end

  describe ".pem" do
    it "retrieves the pem field" do
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:get_field).with("pem").and_return("pem_value")

      pem_value = Semaphore::GithubApp::Credentials::InstanceConfigClient.pem
      expect(pem_value).to eq("pem_value")

      expect(Semaphore::GithubApp::Credentials::InstanceConfigClient).to have_received(:get_field).with("pem")
    end
  end

  describe ".github_application_url" do
    it "retrieves the html_url field" do
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:get_field).with("html_url").and_return("url_value")

      url_value = Semaphore::GithubApp::Credentials::InstanceConfigClient.github_application_url
      expect(url_value).to eq("url_value")

      expect(Semaphore::GithubApp::Credentials::InstanceConfigClient).to have_received(:get_field).with("html_url")
    end
  end

  describe ".github_application_id" do
    it "retrieves the id field" do
      allow(Semaphore::GithubApp::Credentials::InstanceConfigClient).to receive(:get_field).with("app_id").and_return("123")

      id_value = Semaphore::GithubApp::Credentials::InstanceConfigClient.github_application_id
      expect(id_value).to eq("123")

      expect(Semaphore::GithubApp::Credentials::InstanceConfigClient).to have_received(:get_field).with("app_id")
    end
  end
end
