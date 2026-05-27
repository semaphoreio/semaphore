require "spec_helper"

module Semaphore::Events
  RSpec.describe UserUpdatedHandler do
    let(:user_id) { SecureRandom.uuid }
    let(:github_uid) { "184065" }

    describe ".call" do
      context "when the user has a github repo host account" do
        before do
          RepoHostAccount.create!(
            :user_id => user_id,
            :repo_host => ::Repository::GITHUB_PROVIDER,
            :github_uid => github_uid,
            :login => "user-renamed",
            :permission_scope => "repo"
          )
        end

        it "updates stale c_name on rows that match by c_id" do
          GithubAppCollaborator.create!(
            :r_name => "acme/repo",
            :c_name => "user-old",
            :c_id => github_uid,
            :installation_id => 1
          )

          expect(described_class.call(user_id)).to eq(1)

          expect(GithubAppCollaborator.where(:c_id => github_uid).pluck(:c_name))
            .to eq(["user-renamed"])
        end

        it "is a no-op when c_name already matches login" do
          GithubAppCollaborator.create!(
            :r_name => "acme/repo",
            :c_name => "user-renamed",
            :c_id => github_uid,
            :installation_id => 1
          )

          expect(described_class.call(user_id)).to eq(0)
        end

        it "leaves rows with a different c_id untouched" do
          GithubAppCollaborator.create!(
            :r_name => "acme/repo",
            :c_name => "other-user",
            :c_id => "999999",
            :installation_id => 1
          )

          expect(described_class.call(user_id)).to eq(0)

          expect(GithubAppCollaborator.where(:c_id => "999999").pluck(:c_name))
            .to eq(["other-user"])
        end
      end

      context "when the user has no github repo host account" do
        it "returns 0 and does nothing" do
          GithubAppCollaborator.create!(
            :r_name => "acme/repo",
            :c_name => "anyone",
            :c_id => github_uid,
            :installation_id => 1
          )

          expect(described_class.call(user_id)).to eq(0)

          expect(GithubAppCollaborator.where(:c_id => github_uid).pluck(:c_name))
            .to eq(["anyone"])
        end
      end
    end
  end
end
