require "spec_helper"

RSpec.describe GithubAppInstallation, :type => :model do
  describe ".find_by_repository_slug" do
    let!(:installation) do
      FactoryBot.create(
        :github_app_installation,
        :installation_id => 999_101,
        :repositories => [{ "id" => 11, "slug" => "Acme/Example-Repo" }]
      )
    end

    it "finds installation regardless of repository slug letter case" do
      expect(described_class.find_by_repository_slug("AcMe/Example-Repo")).to eq(installation)
      expect(described_class.find_by_repository_slug!("ACME/EXAMPLE-REPO")).to eq(installation)
      expect(installation.reload.repository_slugs).to eq(["Acme/Example-Repo"])
    end
  end

  describe "#replace_repositories!" do
    let(:installation) { FactoryBot.create(:github_app_installation, :installation_id => 999_001, :repositories => initial_repositories) }

    context "when first refresh updates ids from 0 to remote ids" do
      let(:initial_repositories) do
        [
          { "id" => 0, "slug" => "acme/api" },
          { "id" => 0, "slug" => "acme/web" }
        ]
      end

      let(:refreshed_repositories) do
        [
          { "id" => 101, "slug" => "acme/api" },
          { "id" => 202, "slug" => "acme/web" }
        ]
      end

      it "updates ids without changing slugs" do
        installation.replace_repositories!(refreshed_repositories)
        installation.reload

        expect(installation.repositories).to eq(refreshed_repositories)
        expect(installation.repository_slugs).to eq(["acme/api", "acme/web"])
        expect(installation[:repositories]).to eq(["acme/api", "acme/web"])
      end
    end

    context "when refresh adds, removes, and updates ids in one pass" do
      let(:initial_repositories) do
        [
          { "id" => 0, "slug" => "acme/api" },
          { "id" => 0, "slug" => "acme/web" },
          { "id" => 0, "slug" => "acme/old" }
        ]
      end

      let(:refreshed_repositories) do
        [
          { "id" => 111, "slug" => "acme/api" }, # update id
          { "id" => 222, "slug" => "acme/web" }, # update id
          { "id" => 333, "slug" => "acme/new" }  # add
          # acme/old removed
        ]
      end

      it "keeps the set in sync with the incoming list" do
        installation.replace_repositories!(refreshed_repositories)
        installation.reload

        expect(installation.repositories).to eq(refreshed_repositories)
        expect(installation.repository_slugs).to eq(["acme/api", "acme/web", "acme/new"])
        expect(installation[:repositories]).to eq(["acme/api", "acme/web", "acme/new"])
      end
    end

    context "when repository is renamed and id stays the same" do
      let(:initial_repositories) do
        [
          { "id" => 404, "slug" => "acme/old-name" }
        ]
      end

      let(:refreshed_repositories) do
        [
          { "id" => 404, "slug" => "acme/new-name" }
        ]
      end

      it "replaces old slug with new slug" do
        installation.replace_repositories!(refreshed_repositories)
        installation.reload

        expect(installation.repository_slugs).to eq(["acme/new-name"])
        expect(installation.repositories).to eq(refreshed_repositories)
        expect(installation[:repositories]).to eq(["acme/new-name"])
      end
    end

    context "when incoming list has malformed slugs" do
      let(:initial_repositories) do
        [
          { "id" => 1, "slug" => "acme/ok" }
        ]
      end

      let(:refreshed_repositories) do
        [
          { "id" => 10, "slug" => ",Acme/Ok" }, # normalized
          { "id" => 11, "slug" => "bad slug" }, # rejected
          { "id" => 12, "slug" => "" }          # rejected
        ]
      end

      it "stores only normalized valid repositories" do
        installation.replace_repositories!(refreshed_repositories)
        installation.reload

        expect(installation.repositories).to eq([{ "id" => 10, "slug" => "Acme/Ok" }])
        expect(installation.repository_slugs).to eq(["Acme/Ok"])
        expect(installation[:repositories]).to eq(["Acme/Ok"])
      end
    end
  end

  describe "#add_repositories!" do
    let(:installation) do
      FactoryBot.create(
        :github_app_installation,
        :installation_id => 999_201,
        :repositories => [{ "id" => 404, "slug" => "acme/old-name" }]
      )
    end

    it "replaces existing repository when incoming repository has same remote_id and new slug" do
      installation.add_repositories!([{ "id" => 404, "slug" => "acme/new-name" }])
      installation.reload

      expect(installation.repositories).to eq([{ "id" => 404, "slug" => "acme/new-name" }])
      expect(installation.repository_slugs).to eq(["acme/new-name"])
      expect(installation.installation_repositories.where(:remote_id => 404).count).to eq(1)
    end
  end
end
