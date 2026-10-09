require "spec_helper"

RSpec.describe App do
  describe "mergeable-unknown retry settings" do
    let(:keys) { %w[MERGEABLE_UNKNOWN_MAX_RETRIES MERGEABLE_UNKNOWN_RATE_LIMIT_RESERVE] }

    # Settings are read when the config files load, so load them with the given
    # environment, then again with the original one.
    def with_env(values)
      original = keys.index_with { |key| ENV.fetch(key, nil) }
      keys.each { |key| values[key].nil? ? ENV.delete(key) : ENV.store(key, values[key]) }
      reload_app_config
      yield
    ensure
      original.each { |key, value| value.nil? ? ENV.delete(key) : ENV.store(key, value) }
      reload_app_config
    end

    def reload_app_config
      load Rails.root.join("config/app.rb").to_s
      load Rails.root.join("config/app/#{Rails.env}.rb").to_s
    end

    it "defaults to 10 retries and no rate-limit reserve" do
      with_env({}) do
        expect(App.mergeable_unknown_max_retries).to eq(10)
        expect(App.mergeable_unknown_rate_limit_reserve).to eq(0)
      end
    end

    it "reads both settings from the environment" do
      with_env("MERGEABLE_UNKNOWN_MAX_RETRIES" => "3", "MERGEABLE_UNKNOWN_RATE_LIMIT_RESERVE" => "1000") do
        expect(App.mergeable_unknown_max_retries).to eq(3)
        expect(App.mergeable_unknown_rate_limit_reserve).to eq(1000)
      end
    end

    it "treats empty values as not configured" do
      with_env("MERGEABLE_UNKNOWN_MAX_RETRIES" => "", "MERGEABLE_UNKNOWN_RATE_LIMIT_RESERVE" => "") do
        expect(App.mergeable_unknown_max_retries).to eq(10)
        expect(App.mergeable_unknown_rate_limit_reserve).to eq(0)
      end
    end
  end
end
