require "spec_helper"

module RepoHost::Responses::Format
  RSpec.describe Branch do
    describe "#to_h" do
      let(:name) { "name" }
      let(:branch_hash) { { "name" => name } }
      let(:expected_format) { { "name" => name } }

      it "returns branch format" do
        branch = RepoHost::Responses::Format::Branch.new(branch_hash)
        expect(branch.to_h).to eq(expected_format)
      end
    end
  end
end
