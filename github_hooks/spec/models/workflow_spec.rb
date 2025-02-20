require "spec_helper"

RSpec.describe Workflow, :type => :model do
  it { is_expected.to belong_to(:project) }

  describe ".created_before_with_limit" do
    before do
      @wf = FactoryBot.create(:workflow)
    end

    context "when there is only one workflow" do
      it "returns empty list" do
        expect(Workflow.created_before_with_limit(@wf.created_at, 2.minutes)).to be_empty
      end
    end

    context "when there is workflow created before the limit" do
      before do
        FactoryBot.create(:workflow, :created_at => (@wf.created_at - 3.minutes))
      end

      it "returns empty list" do
        expect(Workflow.created_before_with_limit(@wf.created_at, 2.minutes)).to be_empty
      end
    end

    context "when there is workflow created within the limit" do
      before do
        FactoryBot.create(:workflow, :created_at => (@wf.created_at - 1.minute))
      end

      it "returns this workflow" do
        expect(Workflow.created_before_with_limit(@wf.created_at, 2.minutes)).not_to be_empty
      end
    end
  end
end
