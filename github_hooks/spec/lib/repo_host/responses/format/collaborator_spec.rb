require "spec_helper"

module RepoHost::Responses::Format
  RSpec.describe Collaborator do
    describe "#to_h" do
      let(:id) { "id" }
      let(:login) { "login" }
      let(:name) { "name" }
      let(:avatar) { "avatar" }
      let(:collaborator_hash) { { "id" => id, "login" => login, "name" => name, "avatar" => avatar } }
      let(:expected_format) { collaborator_hash }

      it "returns collaborator format" do
        collaborator = RepoHost::Responses::Format::Collaborator.new(collaborator_hash)

        expect(collaborator.to_h).to eq(expected_format)
      end
    end
  end
end
