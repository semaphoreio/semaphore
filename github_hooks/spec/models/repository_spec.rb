require "spec_helper"

RSpec.describe Repository do
  describe ".disconnect_github_app" do
    it "prefers repository_remote_id over repository_slug" do
      allow(Project).to receive(:publish_updated)

      first_project = FactoryBot.create(:project)
      first_project.repository.update!(
        :integration_type => "github_app",
        :url => "git@github.com:acme/one.git",
        :remote_id => "111",
        :connected => true
      )

      second_project = FactoryBot.create(:project)
      second_project.repository.update!(
        :integration_type => "github_app",
        :url => "git@github.com:acme/two.git",
        :remote_id => "222",
        :connected => true
      )

      described_class.disconnect_github_app(
        :repository_slug => "acme/two",
        :repository_remote_id => "111"
      )

      expect(first_project.repository.reload.connected).to be(false)
      expect(second_project.repository.reload.connected).to be(true)
    end

    it "falls back to repository_slug when repository_remote_id is missing" do
      allow(Project).to receive(:publish_updated)

      project = FactoryBot.create(:project)
      project.repository.update!(
        :integration_type => "github_app",
        :url => "git@github.com:acme/fallback.git",
        :remote_id => "",
        :connected => true
      )

      described_class.disconnect_github_app(:repository_slug => "acme/fallback")

      expect(project.repository.reload.connected).to be(false)
    end

    it "falls back to repository_slug when repository_remote_id does not match" do
      allow(Project).to receive(:publish_updated)

      project = FactoryBot.create(:project)
      project.repository.update!(
        :integration_type => "github_app",
        :url => "git@github.com:acme/fallback.git",
        :remote_id => "",
        :connected => true
      )

      described_class.disconnect_github_app(
        :repository_slug => "acme/fallback",
        :repository_remote_id => "999999"
      )

      expect(project.repository.reload.connected).to be(false)
    end
  end

  describe ".connect_github_app" do
    it "prefers repository_remote_id over repository_slug" do
      allow(Project).to receive(:publish_updated)

      first_project = FactoryBot.create(:project)
      first_project.repository.update!(
        :integration_type => "github_app",
        :url => "git@github.com:acme/one.git",
        :remote_id => "111",
        :connected => false
      )

      second_project = FactoryBot.create(:project)
      second_project.repository.update!(
        :integration_type => "github_app",
        :url => "git@github.com:acme/two.git",
        :remote_id => "222",
        :connected => false
      )

      described_class.connect_github_app(
        :repository_slug => "acme/one",
        :repository_remote_id => "222"
      )

      expect(first_project.repository.reload.connected).to be(false)
      expect(second_project.repository.reload.connected).to be(true)
    end

    it "falls back to repository_slug when repository_remote_id does not match" do
      allow(Project).to receive(:publish_updated)

      project = FactoryBot.create(:project)
      project.repository.update!(
        :integration_type => "github_app",
        :url => "git@github.com:acme/fallback.git",
        :remote_id => "",
        :connected => false
      )

      described_class.connect_github_app(
        :repository_slug => "acme/fallback",
        :repository_remote_id => "999999"
      )

      expect(project.repository.reload.connected).to be(true)
    end
  end
end
