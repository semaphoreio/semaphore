require "spec_helper"

vcr_options = { :cassette_name => "PullRequestCommits/pull_request_commits",
                :record => :new_episodes }
RSpec.describe RepoHost::Bitbucket::Payload, :vcr => vcr_options do
  let(:project) { FactoryBot.create(:project, :hash_id => "abcd1234") }
  # Branch events
  let(:payload_for_branch_deletion) { build_payload(RepoHost::Bitbucket::Responses::Payload.branch_deletion) }
  let(:payload_for_new_branch_with_new_commits) do
    build_payload(RepoHost::Bitbucket::Responses::Payload.new_branch_with_new_commits)
  end
  let(:payload_for_new_branch_without_new_commits) do
    build_payload(RepoHost::Bitbucket::Responses::Payload.new_branch_without_new_commits)
  end
  # Pull request events
  let(:payload_for_pull_request_create_commend_on_opened_pr) do
    build_payload(RepoHost::Bitbucket::Responses::Payload.pull_request_create_commend_on_opened_pr)
  end
  let(:payload_for_pull_request_declined) do
    build_payload(RepoHost::Bitbucket::Responses::Payload.pull_request_declined)
  end
  let(:payload_for_pull_request_open_from_fork) do
    build_payload(RepoHost::Bitbucket::Responses::Payload.pull_request_open_from_fork)
  end
  let(:payload_for_pull_request_open) { build_payload(RepoHost::Bitbucket::Responses::Payload.pull_request_open) }
  let(:payload_for_pull_request_push_on_branch_with_opened_pr) do
    build_payload(RepoHost::Bitbucket::Responses::Payload.pull_request_push_on_branch_with_opened_pr)
  end
  let(:payload_for_pull_request_update) { build_payload(RepoHost::Bitbucket::Responses::Payload.pull_request_update) }
  # Push events
  let(:payload_for_push_commit_empty_payload) do
    build_payload(RepoHost::Bitbucket::Responses::Payload.push_commit_empty_payload)
  end
  let(:payload_for_push_commit_force_push) do
    build_payload(RepoHost::Bitbucket::Responses::Payload.push_commit_force_push)
  end
  let(:payload_for_push_multiple_commits) do
    build_payload(RepoHost::Bitbucket::Responses::Payload.push_multiple_commits)
  end
  let(:payload_for_push_commit) { build_payload(RepoHost::Bitbucket::Responses::Payload.push_commit) }
  # Tag events
  let(:payload_for_push_lightweight_tag) { build_payload(RepoHost::Bitbucket::Responses::Payload.push_lightweight_tag) }
  let(:payload_for_push_annotated_tags) { build_payload(RepoHost::Bitbucket::Responses::Payload.push_annotated_tags) }

  def build_payload(string)
    RepoHost::Bitbucket::Payload.new(JSON.parse(string))
  end

  describe "#author_avatar_url" do
    context "branch events" do
      it "returns commit author" do
        expect(payload_for_branch_deletion.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
        expect(payload_for_new_branch_with_new_commits.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
        expect(payload_for_new_branch_without_new_commits.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
      end
    end

    context "pull events" do
      it "returns sender login" do
        expect(payload_for_pull_request_create_commend_on_opened_pr.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
        expect(payload_for_pull_request_declined.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
        expect(payload_for_pull_request_open_from_fork.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
        expect(payload_for_pull_request_open.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
        expect(payload_for_pull_request_push_on_branch_with_opened_pr.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
        expect(payload_for_pull_request_update.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
      end
    end

    context "push events" do
      it "returns pusher name" do
        expect(payload_for_push_commit_force_push.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
        expect(payload_for_push_commit.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
        expect(payload_for_push_lightweight_tag.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
        expect(payload_for_push_annotated_tags.author_avatar_url).to eq "https://secure.gravatar.com/avatar/c4d18a26a4adb99ab6a4c674112158f5?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FMS-6.png"
        expect(payload_for_push_commit_empty_payload.author_avatar_url).to eq "https://bitbucket.org/account/semaphoreci/avatar/"
      end
    end
  end

  describe "#author_name" do
    context "branch events" do
      it "returns commit author" do
        expect(payload_for_branch_deletion.author_name).to eq "milana_stojadinov"
        expect(payload_for_new_branch_with_new_commits.author_name).to eq "milana_stojadinov"
        expect(payload_for_new_branch_without_new_commits.author_name).to eq "milana_stojadinov"
      end
    end

    context "pull events" do
      it "returns sender login" do
        expect(payload_for_pull_request_create_commend_on_opened_pr.author_name).to eq "milana_stojadinov"
        expect(payload_for_pull_request_declined.author_name).to eq "milana_stojadinov"
        expect(payload_for_pull_request_open_from_fork.author_name).to eq "milana_stojadinov"
        expect(payload_for_pull_request_open.author_name).to eq "milana_stojadinov"
        expect(payload_for_pull_request_push_on_branch_with_opened_pr.author_name).to eq "milana_stojadinov"
        expect(payload_for_pull_request_update.author_name).to eq "milana_stojadinov"
      end
    end

    context "push events" do
      it "returns pusher name" do
        expect(payload_for_push_commit_force_push.author_name).to eq "milana_stojadinov"
        expect(payload_for_push_commit.author_name).to eq "milana_stojadinov"
        expect(payload_for_push_multiple_commits.author_name).to eq "semaphoreci"
        expect(payload_for_push_lightweight_tag.author_name).to eq "milana_stojadinov"
        expect(payload_for_push_annotated_tags.author_name).to eq "milana_stojadinov"
        expect(payload_for_push_commit_empty_payload.author_name).to eq "semaphoreci"
      end
    end
  end

  describe "#author_email" do
    context "branch events" do
      it "returns commit author" do
        expect(payload_for_branch_deletion.author_email).to eq ""
        expect(payload_for_new_branch_with_new_commits.author_email).to eq ""
        expect(payload_for_new_branch_without_new_commits.author_email).to eq ""
        expect(payload_for_branch_deletion.commit_author).to eq ""
        expect(payload_for_new_branch_with_new_commits.commit_author).to eq ""
        expect(payload_for_new_branch_without_new_commits.commit_author).to eq ""
      end
    end

    context "pull events" do
      it "returns sender login" do
        expect(payload_for_pull_request_create_commend_on_opened_pr.author_email).to eq ""
        expect(payload_for_pull_request_declined.author_email).to eq ""
        expect(payload_for_pull_request_open_from_fork.author_email).to eq ""
        expect(payload_for_pull_request_open.author_email).to eq ""
        expect(payload_for_pull_request_push_on_branch_with_opened_pr.author_email).to eq ""
        expect(payload_for_pull_request_update.author_email).to eq ""
      end
    end

    context "push events" do
      it "returns pusher name" do
        expect(payload_for_push_commit_force_push.author_email).to eq ""
        expect(payload_for_push_commit.author_email).to eq ""
        expect(payload_for_push_lightweight_tag.author_email).to eq ""
        expect(payload_for_push_annotated_tags.author_email).to eq ""
        expect(payload_for_push_commit_empty_payload.author_email).to eq ""
      end
    end
  end

  describe ".pull_request?" do
    it "returns false for push payload" do
      expect(payload_for_push_commit_empty_payload.pull_request?).to be_falsey
    end

    it "returns true for pull request" do
      expect(payload_for_pull_request_update.pull_request?).to be_truthy
    end

    it "returns false for tag" do
      expect(payload_for_push_lightweight_tag.pull_request?).to be_falsey
    end
  end

  describe ".tag?" do
    it "returns false for push payload" do
      expect(payload_for_push_commit_empty_payload.tag?).to be_falsey
    end

    it "returns false for pull request" do
      expect(payload_for_pull_request_update.tag?).to be_falsey
    end

    it "returns true for tag" do
      expect(payload_for_push_lightweight_tag.tag?).to be_truthy
    end
  end

  describe ".commit_message" do
    it "returns commit message for push" do
      expect(payload_for_push_commit_empty_payload.commit_message).to eq "Mon Oct  4 10:15:57 UTC 2021 - pushn"
      expect(payload_for_push_multiple_commits.commit_message).to eq "most recent commit"
    end

    it "returns commit message for tag" do
      expect(payload_for_push_lightweight_tag.commit_message).to eq "remove lines\n"
    end
  end

  describe ".commit_author" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.commit_author).to eq "Mikołaj Kutryj"
      expect(payload_for_push_multiple_commits.author_name).to eq "semaphoreci"
    end
  end

  describe ".repo_name" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.repo_name).to eq "semaphoreci/foo"
    end
  end

  describe ".pr_head_repo_name" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.pr_head_repo_name).to eq ""
    end
  end

  describe ".pull_request_name" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.pull_request_name).to eq ""
    end
  end

  describe ".pull_request_number" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.pull_request_number).to eq ""
    end
  end

  describe ".repo_url" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.repo_url).to eq "https://bitbucket.org/semaphoreci/foo"
    end
  end

  describe ".pr_head_repo_name" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.pr_head_repo_name).to eq ""
    end
  end

  describe ".pr_head_sha" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.pr_head_sha).to eq ""
    end
  end

  describe ".pr_head_branch_name" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.pr_head_branch_name).to eq ""
    end
  end

  describe ".tag_name" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.tag_name).to eq "master"
    end
  end

  describe ".pr_base_branch_name" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.pr_base_branch_name).to eq ""
    end
  end

  describe ".commit_range" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.commit_range).to eq "3e33408cb14ace049f9f5799caef3afeaeff4b40..."
    end
  end

  describe ".branch_name" do
    it "returns correct data" do
      expect(payload_for_push_commit_empty_payload.branch_name).to eq "master"
    end
  end
end
