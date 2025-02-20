module Semaphore::Bitbucket::Credentials
  @app_id = nil
  @secret_id = nil

  def self.app_id
    @app_id ||= Local.app_id || InstanceConfigClient.app_id
  end

  def self.secret_id
    @secret_id ||= Local.secret_id || InstanceConfigClient.secret_id
  end

  class Local
    def self.app_id
      App.bitbucket_app_id.presence
    end

    def self.secret_id
      App.bitbucket_secret_id.presence
    end
  end

  class InstanceConfigClient
    def self.fetch
      client = InternalApi::InstanceConfig::InstanceConfigService::Stub.new(App.instance_config_url, :this_channel_is_insecure)
      req = InternalApi::InstanceConfig::ListConfigsRequest.new(:types => [InternalApi::InstanceConfig::ConfigType::CONFIG_TYPE_BITBUCKET_APP])

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

      config = response.configs.find { |conf| conf.type == :CONFIG_TYPE_BITBUCKET_APP and conf.state == :STATE_CONFIGURED }

      return if config.nil?

      config.fields.find { |field| field.key == field_name }&.value
    end

    def self.app_id
      get_field("app_id")
    end

    def self.secret_id
      get_field("secret_id")
    end
  end
end
