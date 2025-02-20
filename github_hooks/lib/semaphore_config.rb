module SemaphoreConfig
  class << self

    def method_missing(name)
      env_name = name.to_s.upcase

      if ENV.key?(env_name)
        ENV[env_name]
      else
        config_file[name.to_s]
      end
    end

    def config_file
      @config_file ||= YAML.load(File.read(config_file_path))
    end

    def config_file_path
      ENV["CONFIG_FILE_PATH"] || Rails.root.join("config/config.yml")
    end

  end
end
