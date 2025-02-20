require "spec_helper"

module RepoHost::Responses::Format
  RSpec.describe DeployKey do
    describe "#to_h" do
      let(:id) { "id" }
      let(:deploy_key_hash) { { "id" => id } }
      let(:expected_format) { deploy_key_hash }

      it "returns deploy key format" do
        deploy_key = RepoHost::Responses::Format::DeployKey.new(deploy_key_hash)

        expect(deploy_key.to_h).to eq(expected_format)
      end
    end
  end
end
