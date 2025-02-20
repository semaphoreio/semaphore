require "spec_helper"

module RepoHost::Responses::Format
  RSpec.describe Hook do
    describe "#to_h" do
      let(:id) { "id" }
      let(:hook_hash) { { "id" => id } }
      let(:expected_format) { hook_hash }

      it "returns deploy key format" do
        hook = RepoHost::Responses::Format::Hook.new(hook_hash)

        expect(hook.to_h).to eq(expected_format)
      end
    end
  end
end
