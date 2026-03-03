require "spec_helper"

RSpec.describe Avatar do
  describe ".avatar_url" do
    context "when github_uid is a valid numeric ID" do
      it "returns the GitHub avatar URL with the uid" do
        expect(described_class.avatar_url(12345)).to eq("https://avatars2.githubusercontent.com/u/12345?s=460&v=4")
      end

      it "works with string uid" do
        expect(described_class.avatar_url("67890")).to eq("https://avatars2.githubusercontent.com/u/67890?s=460&v=4")
      end
    end

    context "when github_uid is nil" do
      it "returns the generic avatar URL" do
        expect(described_class.avatar_url(nil)).to eq(Avatar::GENERIC_AVATAR_URL)
      end
    end

    context "when github_uid has user_ prefix (synthetic account)" do
      it "returns the generic avatar URL" do
        expect(described_class.avatar_url("user_123")).to eq(Avatar::GENERIC_AVATAR_URL)
      end
    end

    context "when github_uid has service_account_ prefix (synthetic service account)" do
      it "returns the generic avatar URL" do
        expect(described_class.avatar_url("service_account_456")).to eq(Avatar::GENERIC_AVATAR_URL)
      end
    end
  end

  describe "GENERIC_AVATAR_URL" do
    it "is the expected default avatar" do
      expect(Avatar::GENERIC_AVATAR_URL).to eq("https://avatars2.githubusercontent.com/u/0?s=460&v=4")
    end
  end
end
