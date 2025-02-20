require "spec_helper"

module RepoHost::Responses::Format
  RSpec.describe User do
    describe "#to_h" do
      let(:id) { "id" }
      let(:name) { "name" }
      let(:email) { "email" }
      let(:avatar_url) { "avatar_url" }
      let(:user_hash) { { "id" => id, "name" => name, "email" => email, "avatar_url" => avatar_url } }
      let(:expected_format) { user_hash }

      it "returns deploy key format" do
        user = RepoHost::Responses::Format::User.new(user_hash)

        expect(user.to_h).to eq(expected_format)
      end
    end
  end
end
