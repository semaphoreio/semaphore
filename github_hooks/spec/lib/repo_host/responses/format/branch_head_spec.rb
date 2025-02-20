require "spec_helper"

module RepoHost::Responses::Format
  RSpec.describe BranchHead do
    describe "#to_h" do
      let(:sha) { "sha" }
      let(:html_url) { "html_url" }
      let(:author_name) { "name" }
      let(:author_email) { "author_email" }
      let(:author_date) { "author_date" }
      let(:message) { "message" }
      let(:branch_hash) do
        { "sha" => sha,
          "html_url" => html_url,
          "author_name" => author_name,
          "author_email" => author_email,
          "author_date" => author_date,
          "message" => message }
      end

      let(:expected_format) do
        { "commit" => { "sha" => sha,
                        "html_url" => html_url,
                        "commit" => { "author" => { "name" => author_name,
                                                    "email" => author_email,
                                                    "date" => author_date },
                                      "message" => message } } }
      end

      it "returns branch format" do
        branch_head = BranchHead.new(branch_hash)

        expect(branch_head.to_h).to eq(expected_format)
      end
    end
  end
end
