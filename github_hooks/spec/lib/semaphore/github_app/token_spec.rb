require "spec_helper"

RSpec.describe Semaphore::GithubApp::Token do
  before do
    Semaphore::GithubApp::Credentials.instance_variable_set(:@private_key, nil)
  end

  describe "#installation_token" do
    vcr_options = { :cassette_name => "ProjectIntegrationToken/connection_working" }
    context "connection working", :vcr => vcr_options do
      it "returns github app token for an repository" do
        expect(described_class.installation_token(13545123)).to eq(["v1.faf07f11a0b851f1669ca7ce399aed6683fd9e8c",
                                                                    "2020-12-11T11:41:52Z"])
      end
    end

    vcr_options = { :cassette_name => "ProjectIntegrationToken/ivalid_auth" }
    context "invalid auth", :vcr => vcr_options do
      it "returns github app token for an repository" do
        expect(described_class.installation_token(13545123)).to be_nil
      end
    end
  end

  describe "#repository_token" do
    before do
      FactoryBot.create(:github_app_installation, :installation_id => 13545123, :repositories => ["renderedtext/guard"])
    end

    vcr_options = { :cassette_name => "ProjectIntegrationToken/connection_working" }
    context "connection working", :vcr => vcr_options do
      it "returns github app token for a repository" do
        expect(described_class.repository_token(:repository_slug => "renderedtext/guard")).to eq([
                                                                                                   "v1.faf07f11a0b851f1669ca7ce399aed6683fd9e8c", "2020-12-11T11:41:52Z"
                                                                                                 ])
      end

      it "returns nil for an invalid repository" do
        expect(described_class.repository_token(:repository_slug => "semaphoreio/semaphore")).to be_nil
      end

      it "uses repository_remote_id when provided" do
        FactoryBot.create(
          :github_app_installation,
          :installation_id => 13545124,
          :repositories => [{ "id" => 42, "slug" => "renderedtext/other" }]
        )

        allow(described_class).to receive(:installation_token).with(13545124).and_return(["token", "2020-12-11T11:41:52Z"])

        expect(described_class.repository_token(:repository_slug => "renderedtext/guard", :repository_remote_id => 42)).to eq(["token", "2020-12-11T11:41:52Z"])
      end

      it "falls back to repository_slug when repository_remote_id is not found" do
        allow(described_class).to receive(:installation_token).with(13545123).and_return(["token", "2020-12-11T11:41:52Z"])

        expect(described_class.repository_token(:repository_slug => "renderedtext/guard", :repository_remote_id => 999_999)).to eq(["token", "2020-12-11T11:41:52Z"])
      end

      it "does not use repository_remote_id lookup for zero value" do
        allow(described_class).to receive(:installation_token).with(13545123).and_return(["token", "2020-12-11T11:41:52Z"])

        expect(described_class.repository_token(:repository_slug => "renderedtext/guard", :repository_remote_id => 0)).to eq(["token", "2020-12-11T11:41:52Z"])
      end
    end
  end

  describe "#repository_installation_id" do
    before { allow(described_class).to receive(:generate_jwt).and_return("jwt") }

    it "returns the installation id on success" do
      allow(Excon).to receive(:get).and_return(
        instance_double(Excon::Response, :status => 200, :data => { :body => JSON.generate({ "id" => 4242 }) })
      )

      expect(described_class.repository_installation_id("acme/widget")).to eq(4242)
      expect(Excon).to have_received(:get).with(
        "https://api.github.com/repos/acme/widget/installation",
        :headers => {
          "User-Agent" => "Awesome-Octocat-App",
          "Authorization" => "Bearer jwt",
          "Accept" => "application/vnd.github.v3+json"
        }
      )
    end

    it "returns nil when the app is not installed on the repository" do
      allow(Excon).to receive(:get).and_return(
        instance_double(Excon::Response, :status => 404, :data => { :body => "{}" })
      )

      expect(described_class.repository_installation_id("acme/widget")).to be_nil
    end

    it "returns nil on a transport error" do
      allow(Excon).to receive(:get).and_raise(StandardError.new("boom"))

      expect(described_class.repository_installation_id("acme/widget")).to be_nil
    end

    it "returns nil when a 2xx response carries no id (never 0)" do
      allow(Excon).to receive(:get).and_return(
        instance_double(Excon::Response, :status => 200, :data => { :body => "{}" })
      )

      expect(described_class.repository_installation_id("acme/widget")).to be_nil
    end

    it "returns nil when a 2xx id is not a positive integer" do
      allow(Excon).to receive(:get).and_return(
        instance_double(Excon::Response, :status => 200, :data => { :body => JSON.generate({ "id" => "nan" }) })
      )

      expect(described_class.repository_installation_id("acme/widget")).to be_nil
    end
  end

  describe "#organization_installation_id" do
    before { allow(described_class).to receive(:generate_jwt).and_return("jwt") }

    it "returns the installation id on success" do
      allow(Excon).to receive(:get).and_return(
        instance_double(Excon::Response, :status => 200, :data => { :body => JSON.generate({ "id" => 9090 }) })
      )

      expect(described_class.organization_installation_id("acme")).to eq(9090)
      expect(Excon).to have_received(:get).with(
        "https://api.github.com/orgs/acme/installation",
        :headers => {
          "User-Agent" => "Awesome-Octocat-App",
          "Authorization" => "Bearer jwt",
          "Accept" => "application/vnd.github.v3+json"
        }
      )
    end

    it "returns nil when the app is not installed on the organization" do
      allow(Excon).to receive(:get).and_return(
        instance_double(Excon::Response, :status => 404, :data => { :body => "{}" })
      )

      expect(described_class.organization_installation_id("acme")).to be_nil
    end

    it "returns nil on a transport error" do
      allow(Excon).to receive(:get).and_raise(StandardError.new("boom"))

      expect(described_class.organization_installation_id("acme")).to be_nil
    end
  end
end
