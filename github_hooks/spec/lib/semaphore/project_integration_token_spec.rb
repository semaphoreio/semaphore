require "spec_helper"

RSpec.describe Semaphore::ProjectIntegrationToken do
  describe "#github_oauth_token" do
    before do
      @user = FactoryBot.create(:user)
      @repo = FactoryBot.create(:repo_host_account, :user => @user)
    end

    it "returns github oauth token of an user" do
      expect(described_class.new.github_oauth_token(@user)).to eq([@repo.token, nil])
    end
  end

  # guard is the only component that may refresh these, so the token comes from
  # guard and never from the stored row, which can be past its expiry.
  %w[bitbucket gitlab].each do |integration_type|
    describe "##{integration_type}_oauth_token" do
      let(:method) { :"#{integration_type}_oauth_token" }
      let(:expires_at) { Time.zone.now.change(:usec => 0) }

      before do
        @user = FactoryBot.create(:user)
      end

      it "returns the credential guard hands out" do
        allow(Semaphore::GuardUserClient).to receive(:repository_token)
          .with(@user.id, integration_type)
          .and_return(["guard-token", expires_at])

        expect(described_class.new.public_send(method, @user))
          .to eq(["guard-token", expires_at])
      end

      it "never talks to the provider" do
        allow(Semaphore::GuardUserClient).to receive(:repository_token)
          .and_return(["guard-token", nil])

        expect(Excon).not_to receive(:post)
        expect(Excon).not_to receive(:get)

        described_class.new.public_send(method, @user)
      end

      # get_token feeds this into a proto3 string field, which rejects nil.
      context "when guard has no usable credential" do
        it "returns an empty credential instead of raising" do
          allow(Semaphore::GuardUserClient).to receive(:repository_token)
            .and_raise(GRPC::NotFound.new("Token for not found."))

          expect(described_class.new.public_send(method, @user)).to eq(["", nil])
        end
      end

      context "when guard is unreachable" do
        it "returns an empty credential instead of raising" do
          allow(Semaphore::GuardUserClient).to receive(:repository_token)
            .and_raise(StandardError, "boom")

          expect(described_class.new.public_send(method, @user)).to eq(["", nil])
        end
      end
    end
  end

  describe "#github_app_token" do
    it "returns github app token for an repository" do
      allow(Semaphore::GithubApp::Token).to receive(:repository_token).with(
        :repository_slug => "renderedtext/guard",
        :repository_remote_id => nil
      ).and_return("foo")

      expect(described_class.new.github_app_token(:repository_slug => "renderedtext/guard")).to eq("foo")
    end
  end

  describe "#project_token" do
    context "project based on github_oauth_token integration" do
      before do
        user = FactoryBot.create(:user)
        @repo = FactoryBot.create(:repo_host_account, :user => user)

        @project = FactoryBot.create(:project, :creator => user)
        @project.repository.update(:integration_type => "github_oauth_token")
      end

      it "returns github_app token" do
        expect(described_class.new.project_token(@project)).to eq([@repo.token, nil])
      end

    end

    context "project based on github_app integration" do
      before do
        @project = FactoryBot.create(:project)
        @project.repository.update(:integration_type => "github_app")
      end

      it "returns github_app token" do
        allow(Semaphore::GithubApp::Token).to receive(:repository_token)
          .with(
            :repository_slug => @project.repo_owner_and_name,
            :repository_remote_id => @project.repository.remote_id
          ).and_return("foo")

        expect(described_class.new.project_token(@project)).to eq("foo")
      end
    end
  end
end
