require "spec_helper"

module Semaphore::GithubApp
  RSpec.describe Hook do
    before do
      allow(Tackle).to receive(:publish)
    end

    describe ".process" do
      let(:installation_id) { 13609976 }

      context "new installation" do
        let(:event) { "installation" }
        let(:payload) { JSON.parse(RepoHost::Github::Responses::Payload.installation_created) }

        it "creates new GithubAppInstallation" do
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_in).twice

          project = FactoryBot.create(:project)
          project.repository.update(
            :integration_type => "github_app",
            :url => "git@github.com:renderedtext/guard.git",
            :connected => false
          )

          expect(project.repository.connected).to be(false)

          expect do
            described_class.process(event, payload)
          end.to change(GithubAppInstallation, :count).from(0).to(1)

          installation = find_installation(installation_id)

          expect(installation.suspended_at).to be_nil
          expect(installation.permissions_accepted_at).to be_nil
          expect(installation.repositories).to eq(["renderedtext/guard", "semaphoreio/semaphore"])
          expect(project.repository.reload.connected).to be(true)

          expect(Tackle).to have_received(:publish).with(
            anything, hash_including(:exchange => "project_exchange", :routing_key => "updated")
          )
        end
      end

      context "delete installation" do
        let(:event) { "installation" }
        let(:payload) { JSON.parse(RepoHost::Github::Responses::Payload.installation_deleted) }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => installation_id)
        end

        it "mark installation as deleted" do
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_in).twice

          project = FactoryBot.create(:project)
          project.repository.update(
            :integration_type => "github_app",
            :url => "git@github.com:renderedtext/guard.git",
            :connected => true
          )

          expect(project.repository.connected).to be(true)

          installation = find_installation(installation_id)

          described_class.process(event, payload)

          installation = find_installation(installation_id)

          expect(installation).to be_nil
          expect(project.repository.reload.connected).to be(false)
          expect(Tackle).to have_received(:publish).with(
            anything, hash_including(:exchange => "project_exchange", :routing_key => "updated")
          )
        end
      end

      context "suspend installation" do
        let(:event) { "installation" }
        let(:payload) { JSON.parse(RepoHost::Github::Responses::Payload.installation_suspended) }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => installation_id)
        end

        it "mark installation as suspend" do
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_in).twice

          project = FactoryBot.create(:project)
          project.repository.update(
            :integration_type => "github_app",
            :url => "git@github.com:renderedtext/guard.git",
            :connected => true
          )

          expect(project.repository.connected).to be(true)

          installation = find_installation(installation_id)

          expect(installation.suspended_at).to be_nil

          described_class.process(event, payload)

          installation.reload
          expect(installation.suspended_at).not_to be_nil
          expect(project.repository.reload.connected).to be(false)
          expect(Tackle).to have_received(:publish).with(
            anything, hash_including(:exchange => "project_exchange", :routing_key => "updated")
          )
        end
      end

      context "unsuspend installation" do
        let(:event) { "installation" }
        let(:payload) { JSON.parse(RepoHost::Github::Responses::Payload.installation_unsuspended) }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => installation_id,
                                                      :suspended_at => Time.zone.now)
        end

        it "mark installation as unsuspend" do
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_in).twice

          project = FactoryBot.create(:project)
          project.repository.update(
            :integration_type => "github_app",
            :url => "git@github.com:renderedtext/guard.git",
            :connected => false
          )

          expect(project.repository.connected).to be(false)

          installation = find_installation(installation_id)

          expect(installation.suspended_at).not_to be_nil

          described_class.process(event, payload)

          installation.reload
          expect(installation.suspended_at).to be_nil
          expect(project.repository.reload.connected).to be(true)
          expect(Tackle).to have_received(:publish).with(
            anything, hash_including(:exchange => "project_exchange", :routing_key => "updated")
          )
        end
      end

      context "accept new permissions" do
        let(:event) { "installation" }
        let(:payload) { JSON.parse(RepoHost::Github::Responses::Payload.installation_new_permissions_accepted) }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => installation_id)
        end

        it "updates accepted perrmisions date on installation)" do
          installation = find_installation(installation_id)

          expect(installation.permissions_accepted_at).to be_nil

          described_class.process(event, payload)

          installation.reload
          expect(installation.permissions_accepted_at).not_to be_nil
          expect(Tackle).not_to have_received(:publish).with(
            anything, hash_including(:exchange => "project_exchange", :routing_key => "updated")
          )
        end
      end

      context "add repositories" do
        let(:event) { "installation_repositories" }
        let(:payload) { JSON.parse(RepoHost::Github::Responses::Payload.installation_repositories_added) }
        let(:repositories) { ["renderedtext/foo"] }
        let(:new_repositories) { ["renderedtext/foo", "semaphoreio/semaphore"] }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => SecureRandom.uuid,
                                                      :repositories => ["foo/bar"])
          FactoryBot.create(:github_app_installation, :installation_id => installation_id,
                                                      :repositories => repositories)
        end

        it "add repositories to installation" do
          installation = find_installation(installation_id)

          expect(installation.repositories).to eq(repositories)
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_in).once

          project = FactoryBot.create(:project)
          project.repository.update(
            :integration_type => "github_app",
            :url => "git@github.com:semaphoreio/semaphore.git",
            :connected => false
          )

          expect(project.repository.connected).to be(false)

          described_class.process(event, payload)

          installation.reload
          expect(installation.repositories.sort).to eq(new_repositories.sort)
          expect(project.repository.reload.connected).to be(true)
          expect(Tackle).to have_received(:publish).with(
            anything, hash_including(:exchange => "project_exchange", :routing_key => "updated")
          )
        end
      end

      context "remove repositories" do
        let(:event) { "installation_repositories" }
        let(:payload) { JSON.parse(RepoHost::Github::Responses::Payload.installation_repositories_removed) }
        let(:repositories) { ["renderedtext/foo", "semaphoreio/semaphore"] }
        let(:new_repositories) { ["renderedtext/foo"] }

        before do
          FactoryBot.create(:github_app_installation, :installation_id => installation_id,
                                                      :repositories => repositories)
        end

        it "remove repositories from installation" do
          installation = find_installation(installation_id)

          expect(installation.repositories).to eq(repositories)
          expect(Semaphore::GithubApp::Collaborators::Worker).to receive(:perform_in).once

          project = FactoryBot.create(:project)
          project.repository.update(
            :integration_type => "github_app",
            :url => "git@github.com:semaphoreio/semaphore.git",
            :connected => true
          )

          expect(project.repository.connected).to be(true)

          described_class.process(event, payload)

          installation.reload
          expect(installation.repositories).to eq(new_repositories)
          expect(project.repository.reload.connected).to be(false)
          expect(Tackle).to have_received(:publish).with(
            anything, hash_including(:exchange => "project_exchange", :routing_key => "updated")
          )
        end
      end

      def find_installation(installation_id)
        GithubAppInstallation.find_by(:installation_id => installation_id)
      end
    end

    describe ".verify_signature" do
      let(:payload) { RepoHost::Github::Responses::Payload.installation_created }
      let(:signature) { "sha256=fe4f21865972070cb4743aa008614042a26f6cb69e06d6a9b6d913ee594d23d7" }
      let(:github_app_webhook_secret) { "secret" }

      it "returns :ok when the signature is valid" do
        expect(described_class.webhook_signature_valid?(github_app_webhook_secret, signature, payload)).to eq(:ok)
      end

      it "returns :not_verified when the signature is not valid" do
        expect(described_class.webhook_signature_valid?(github_app_webhook_secret, "bad-signature", payload)).to eq(:not_verified)
      end
    end
  end
end
