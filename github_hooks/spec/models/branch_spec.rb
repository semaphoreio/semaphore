require "spec_helper"

RSpec.describe Branch, :type => :model do

  let(:build) { FactoryBot.create(:build) }
  let(:branch) { FactoryBot.create(:branch) }
  let(:project) { FactoryBot.create(:project) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:project) }

  context "uniquness validation" do
    before { FactoryBot.create(:branch) }

    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id) }
  end

  it { is_expected.to belong_to(:project) }

  describe ".by_updated_at" do
    before do
      @branch_1 = FactoryBot.create(:branch)
      @branch_2 = FactoryBot.create(:branch)

      @branch_1.touch
    end

    it "returns branches ordered by updated_at" do
      expect(Branch.by_updated_at).to eq([@branch_1, @branch_2])
    end
  end

  describe "creation with strange branch names" do
    it "does not touch branch name" do
      branch = Branch.create!(:name => "feature/image", :project => project)

      expect(branch.name).to eq("feature/image")
    end

    it "doesn't apply friendly_id blacklist" do
      branch = Branch.new(:name => "new", :project => project)

      expect(branch).to be_valid
    end
  end

  describe "#pull_request?" do
    context "branch is pull request" do
      before do
        @branch = FactoryBot.create(:branch, :pull_request_number => 1)
      end

      it "sets automatic deploy for server to false" do
        expect(@branch.pull_request?).to be_truthy
      end
    end
  end
end
