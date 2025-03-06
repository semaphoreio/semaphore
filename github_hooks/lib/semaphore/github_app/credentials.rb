module Semaphore::GithubApp::Credentials
  @private_key = nil
  @github_application_url = nil
  @github_application_id = nil
  @github_client_id = nil
  @github_client_secret = nil
  @github_app_webhook_secret = nil

  def self.private_key
    @private_key ||= Local.pem || InstanceConfigClient.pem
  end

  def self.github_application_url
    @github_application_url ||= Local.github_application_url || InstanceConfigClient.github_application_url
  end

  def self.github_application_id
    @github_application_id ||= Local.github_application_id || InstanceConfigClient.github_application_id
  end

  def self.github_client_id
    @github_client_id ||=  InstanceConfigClient.github_client_id || Local.github_client_id
  end

  def self.github_client_secret
    @github_client_secret ||= InstanceConfigClient.github_client_secret || Local.github_client_secret
  end

  def self.github_app_webhook_secret
    @github_app_webhook_secret ||= InstanceConfigClient.github_app_webhook_secret || Local.github_app_webhook_secret
  end

  class Local
    def self.pem
      if File.exist?(App.github_application_key_path) # function
        File.read(App.github_application_key_path)
      end
    end

    def self.github_application_url
      App.github_application_url.presence
    end

    def self.github_application_id
      App.github_application_id.presence
    end

    def self.github_client_id
      App.github_app_id.presence
    end

    def self.github_client_secret
      App.github_secret_id.presence
    end

    def self.github_app_webhook_secret
      App.github_app_webhook_secret.presence
    end
  end

  class InstanceConfigClient
    def self.fetch
      client = InternalApi::InstanceConfig::InstanceConfigService::Stub.new(App.instance_config_url, :this_channel_is_insecure)
      req = InternalApi::InstanceConfig::ListConfigsRequest.new(:types => [InternalApi::InstanceConfig::ConfigType::CONFIG_TYPE_GITHUB_APP])

      begin
        response = client.list_configs(req)
        return nil if response.configs.empty?

        response
      rescue StandardError => e
        Logman.error "Error while fetching config with req #{req.inspect}. Error: #{e.inspect}"
        nil
      end
    end

    def self.get_field(field_name)
      response = fetch
      return if response.nil?

      config = response.configs.find { |conf| conf.type == :CONFIG_TYPE_GITHUB_APP and conf.state == :STATE_CONFIGURED }

      return if config.nil?

      config.fields.find { |field| field.key == field_name }&.value
    end

    def self.pem
      get_field("pem")
    end

    def self.github_application_url
      get_field("html_url")
    end

    def self.github_application_id
      get_field("app_id")
    end

    def self.github_client_id
      get_field("client_id")
    end

    def self.github_app_webhook_secret
      get_field("webhook_secret")
    end

    def self.github_client_secret
      get_field("client_secret")
    end
  end
end
