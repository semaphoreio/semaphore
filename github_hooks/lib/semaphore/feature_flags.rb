module Semaphore
  # Mirrors FeatureProvider in the Elixir services: on-prem reads the mounted
  # features YAML (FEATURE_YAML_PATH), otherwise asks feature hub per org.
  # Any lookup failure reports the feature as disabled.
  module FeatureFlags
    TIMEOUT = 3

    module_function

    def enabled?(feature_type, org_id)
      yaml_path = SemaphoreConfig.feature_yaml_path

      if yaml_path.present?
        yaml_enabled?(yaml_path, feature_type.to_s)
      else
        hub_enabled?(org_id, feature_type.to_s)
      end
    rescue StandardError => e
      Rails.logger.error("feature-flag-lookup-failed feature=#{feature_type} org_id=#{org_id} error=#{e.class}")
      Watchman.increment("feature_flags.lookup_failed")
      false
    end

    def yaml_enabled?(path, feature_type)
      features = YAML.safe_load_file(path) || {}
      return false unless features.key?(feature_type)

      setup = features[feature_type]
      !setup.is_a?(Hash) || setup["enabled"] != false
    end

    def hub_enabled?(org_id, feature_type)
      return false if org_id.blank?

      request = InternalApi::Feature::ListOrganizationFeaturesRequest.new(:org_id => org_id)
      response = stub.list_organization_features(request, :deadline => Time.now.utc + TIMEOUT)

      response.organization_features.any? do |org_feature|
        org_feature.feature&.type == feature_type && org_feature.availability&.state == :ENABLED
      end
    end

    def stub
      InternalApi::Feature::FeatureService::Stub.new(App.feature_api_url, :this_channel_is_insecure)
    end
  end
end
