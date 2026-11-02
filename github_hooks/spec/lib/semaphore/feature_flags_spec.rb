require "spec_helper"

RSpec.describe Semaphore::FeatureFlags, :aggregate_failures do
  let(:org_id) { SecureRandom.uuid }

  around do |example|
    previous = ENV.fetch("FEATURE_YAML_PATH", nil)
    ENV["FEATURE_YAML_PATH"] = yaml_path
    example.run
  ensure
    ENV["FEATURE_YAML_PATH"] = previous
  end

  before do
    allow(Watchman).to receive(:increment)
  end

  context "when a features YAML file is configured" do
    let(:yaml_file) do
      Tempfile.new(["features", ".yml"]).tap do |file|
        file.write(<<~YAML)
          sem_approve_options:
            enabled: true
          explicitly_disabled:
            enabled: false
          bare_key:
          quantity_only:
            quantity: 5
        YAML
        file.flush
      end
    end
    let(:yaml_path) { yaml_file.path }

    after { yaml_file.close! }

    it "is enabled for listed features unless they set enabled: false" do
      expect(described_class.enabled?(:sem_approve_options, org_id)).to be(true)
      expect(described_class.enabled?("bare_key", org_id)).to be(true)
      expect(described_class.enabled?(:quantity_only, org_id)).to be(true)
      expect(described_class.enabled?(:explicitly_disabled, org_id)).to be(false)
    end

    it "is disabled for features missing from the file" do
      expect(described_class.enabled?(:unknown_feature, org_id)).to be(false)
    end

    it "does not call feature hub" do
      expect(described_class).not_to receive(:stub)

      described_class.enabled?(:sem_approve_options, org_id)
    end
  end

  context "when the configured features YAML file cannot be read" do
    let(:yaml_path) { "/nonexistent/features.yml" }

    it "fails closed" do
      expect(Watchman).to receive(:increment).with("feature_flags.lookup_failed")
      expect(described_class.enabled?(:sem_approve_options, org_id)).to be(false)
    end
  end

  context "when no features YAML file is configured" do
    let(:yaml_path) { nil }
    let(:feature_stub) { instance_double(InternalApi::Feature::FeatureService::Stub) }

    def org_feature(type, state)
      InternalApi::Feature::OrganizationFeature.new(
        :feature => InternalApi::Feature::Feature.new(:type => type),
        :availability => InternalApi::Feature::Availability.new(:state => state)
      )
    end

    def respond_with(*features)
      allow(feature_stub).to receive(:list_organization_features).and_return(
        InternalApi::Feature::ListOrganizationFeaturesResponse.new(:organization_features => features)
      )
    end

    before do
      allow(described_class).to receive(:stub).and_return(feature_stub)
    end

    it "is enabled only when feature hub reports the feature as ENABLED for the org" do
      respond_with(org_feature("other_feature", :ENABLED), org_feature("sem_approve_options", :ENABLED))

      expect(described_class.enabled?(:sem_approve_options, org_id)).to be(true)
      expect(feature_stub).to have_received(:list_organization_features)
        .with(InternalApi::Feature::ListOrganizationFeaturesRequest.new(:org_id => org_id), :deadline => kind_of(Time))
    end

    it "is disabled for hidden or zero-state features" do
      respond_with(org_feature("sem_approve_options", :HIDDEN))
      expect(described_class.enabled?(:sem_approve_options, org_id)).to be(false)

      respond_with(org_feature("sem_approve_options", :ZERO_STATE))
      expect(described_class.enabled?(:sem_approve_options, org_id)).to be(false)
    end

    it "is disabled when feature hub does not list the feature" do
      respond_with(org_feature("other_feature", :ENABLED))

      expect(described_class.enabled?(:sem_approve_options, org_id)).to be(false)
    end

    it "is disabled without calling feature hub when the org id is blank" do
      expect(feature_stub).not_to receive(:list_organization_features)

      expect(described_class.enabled?(:sem_approve_options, "")).to be(false)
    end

    it "fails closed when feature hub errors" do
      allow(feature_stub).to receive(:list_organization_features).and_raise(GRPC::Unavailable)

      expect(Watchman).to receive(:increment).with("feature_flags.lookup_failed")
      expect(described_class.enabled?(:sem_approve_options, org_id)).to be(false)
    end
  end
end
