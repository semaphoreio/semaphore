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
        expect(described_class.repository_token("renderedtext/guard")).to eq([
                                                                               "v1.faf07f11a0b851f1669ca7ce399aed6683fd9e8c", "2020-12-11T11:41:52Z"
                                                                             ])
      end

      it "returns nil for an invalid repository" do
        expect(described_class.repository_token("semaphoreio/semaphore")).to be_nil
      end

      it "uses repository_remote_id when provided" do
        FactoryBot.create(
          :github_app_installation,
          :installation_id => 13545124,
          :repositories => [{ "id" => 42, "slug" => "renderedtext/other" }]
        )

        allow(described_class).to receive(:installation_token).with(13545124).and_return(["token", "2020-12-11T11:41:52Z"])

        expect(described_class.repository_token("renderedtext/guard", :repository_remote_id => 42)).to eq(["token", "2020-12-11T11:41:52Z"])
      end

      it "falls back to repository_slug when repository_remote_id is not found" do
        allow(described_class).to receive(:installation_token).with(13545123).and_return(["token", "2020-12-11T11:41:52Z"])

        expect(described_class.repository_token("renderedtext/guard", :repository_remote_id => 999_999)).to eq(["token", "2020-12-11T11:41:52Z"])
      end

      it "does not use repository_remote_id lookup for zero value" do
        allow(described_class).to receive(:installation_token).with(13545123).and_return(["token", "2020-12-11T11:41:52Z"])

        expect(described_class.repository_token("renderedtext/guard", :repository_remote_id => 0)).to eq(["token", "2020-12-11T11:41:52Z"])
      end
    end
  end
end
