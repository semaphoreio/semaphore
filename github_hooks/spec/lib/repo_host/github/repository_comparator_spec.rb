require "spec_helper"

RSpec.describe RepoHost::Github::RepositoryComparator do

  describe "#different?" do
    it "returns false when name and default branch are unchanged" do
      repository = FactoryBot.create(
        :repository,
        :owner => "radwo",
        :name => "refactored-octo-spoon-two",
        :default_branch => "master"
      )
      comparator = described_class.new(
        repository,
        RepoHost::Github::Responses::Payload.repository_renamed_hook
      )

      expect(comparator.different?).to be(false)
      expect(comparator.changes).to eq(
        :name_changed => false,
        :default_branch_changed => false
      )
    end

    it "detects a default branch change" do
      repository = FactoryBot.create(
        :repository,
        :owner => "renderedtext",
        :name => "guard",
        :default_branch => "main"
      )
      comparator = described_class.new(
        repository,
        RepoHost::Github::Responses::Payload.default_branch_changed
      )

      expect(comparator.different?).to be(true)
      expect(comparator.changes).to include(
        :default_branch_changed => true,
        :name_changed => false
      )
    end

    it "detects a repository rename" do
      repository = FactoryBot.create(
        :repository,
        :owner => "radwo",
        :name => "refactored-octo-spoon",
        :default_branch => "master"
      )
      comparator = described_class.new(
        repository,
        RepoHost::Github::Responses::Payload.repository_renamed_hook
      )

      expect(comparator.different?).to be(true)
      expect(comparator.changes).to include(
        :name_changed => true,
        :default_branch_changed => false
      )
    end
  end
end
