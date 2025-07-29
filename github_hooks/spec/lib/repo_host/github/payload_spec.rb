require "spec_helper"

vcr_options = { :cassette_name => "PullRequestCommits/pull_request_commits",
                :record => :new_episodes }
RSpec.describe RepoHost::Github::Payload, :vcr => vcr_options do

  let(:project) { FactoryBot.create(:project, :hash_id => "abcd1234") }
  let(:payload) { RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook) }
  let(:payload_for_created_branch) do
    RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook_on_created_branch)
  end
  let(:payload_for_deleted_branch) do
    RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook_on_deleted_branch)
  end
  let(:payload_for_created_tag) do
    RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook_on_created_tag)
  end
  let(:payload_with_ci_skip) { RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.with_ci_skip) }
  let(:payload_with_skip_ci) { RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.with_skip_ci) }
  let(:payload_with_forced_pushed_branch) do
    RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook_with_force_pushed_branch)
  end
  let(:payload_for_opened_pull_request) do
    RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request)
  end
  let(:payload_for_opened_draft_pull_request) do
    RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_draft_hook_pull_request)
  end
  let(:payload_for_issue_comment) do
    RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook_issue_comment)
  end
  let(:payload_for_closed_pull_request) do
    RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request_closed)
  end
  let(:payload_for_commit_pull_request) do
    RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request_commit)
  end
  let(:payload_without_commits) do
    RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.without_commits_hook)
  end
  let(:github_app_bot_push) do
    RepoHost::Github::Payload.new(RepoHost::Github::Responses::Payload.github_app_push_as_bot)
  end

  describe "#author_avatar_url" do
    context "github app bot push" do
      it "returns commit author" do
        expect(github_app_bot_push.author_avatar_url).to eq "https://avatars.githubusercontent.com/darkofabijan?v=4"
      end
    end

    context "pull request commit" do
      it "returns sender login" do
        expect(payload_for_commit_pull_request.author_avatar_url).to eq "https://avatars.githubusercontent.com/u/695790?v=4"
      end
    end

    context "push" do
      it "returns pusher name" do
        expect(payload_with_forced_pushed_branch.author_avatar_url).to eq "https://avatars.githubusercontent.com/j1mr10rd4n?v=4"
      end
    end
  end

  describe "#author_name" do
    context "github app bot push" do
      it "returns commit author" do
        expect(github_app_bot_push.author_name).to eq "darkofabijan"
      end
    end

    context "pull request commit" do
      it "returns sender login" do
        expect(payload_for_commit_pull_request.author_name).to eq "rastasheep"
      end
    end

    context "push" do
      it "returns pusher name" do
        expect(payload_with_forced_pushed_branch.author_name).to eq "j1mr10rd4n"
      end
    end
  end

  describe "#author_email" do
    context "github app bot push" do
      it "returns commit author email" do
        expect(github_app_bot_push.author_email).to eq "darko.fabijan@gmail.com"
      end
    end

    context "pull request commit" do
      it "returns pusher email" do
        expect(payload_for_commit_pull_request.author_email).to be_nil
      end
    end

    context "push" do
      it "returns pusher email" do
        expect(payload_with_forced_pushed_branch.author_email).to eq "jim@j1mr10rd4n.info"
      end
    end
  end

  describe ".is_pull_request?" do
    context "payload has pull request info" do
      it "returns true" do
        expect(payload_for_opened_pull_request.is_pull_request?).to be_truthy
      end
    end

    context "payload does not have pull request info" do
      it "returns false" do
        expect(payload.is_pull_request?).to be_falsey
      end
    end
  end

  describe ".is_draft_pull_request?" do
    context "payload has draft pull request info" do
      it "returns true" do
        expect(payload_for_opened_draft_pull_request.is_pull_request?).to be_truthy
      end
    end

    context "payload does not have draft pull request info" do
      it "returns false" do
        expect(payload.is_draft_pull_request?).to be_falsey
      end
    end
  end

  describe ".pull_request_opened" do
    context "pull request opened" do
      before do
        allow(payload_for_opened_pull_request).to receive(:extract_action).and_return(RepoHost::Github::Payload::PULL_REQUEST_OPENED)
      end

      it "returns true" do
        expect(payload_for_opened_pull_request.pull_request_opened?).to be_truthy
      end
    end

    context "pull request is not opened" do
      before do
        allow(payload).to receive(:extract_action).and_return(RepoHost::Github::Payload::PULL_REQUEST_CLOSED)
      end

      it "returns false" do
        expect(payload.pull_request_opened?).to be_falsey
      end
    end
  end

  describe ".pull_request_commit" do
    context "pull request commit" do
      before do
        allow(payload_for_opened_pull_request).to receive(:extract_action).and_return(RepoHost::Github::Payload::PULL_REQUEST_COMMIT)
      end

      it "returns true" do
        expect(payload_for_commit_pull_request.pull_request_commit?).to be_truthy
      end
    end
  end

  describe ".pull_request_closed" do
    context "pull request closed" do
      before do
        allow_any_instance_of(RepoHost::Github::Payload).to receive(:extract_commits)
        allow(payload_for_closed_pull_request).to receive(:extract_action).and_return(RepoHost::Github::Payload::PULL_REQUEST_CLOSED)
      end

      it "returns true" do
        expect(payload_for_closed_pull_request.pull_request_closed?).to be_truthy
      end
    end

    context "pull request is not closed" do
      before do
        allow(payload).to receive(:extract_action).and_return(RepoHost::Github::Payload::PULL_REQUEST_OPENED)
      end

      it "returns false" do
        expect(payload.pull_request_closed?).to be_falsey
      end
    end
  end

  describe ".pull_request_number" do

    context "payload from push event" do
      it "returns pull request number" do
        expect(payload_for_opened_pull_request.pull_request_number).to eq(1)
      end
    end

  end

  describe ".pull_request_name" do

    context "payload from push event" do
      it "returns pull request number" do
        expect(payload_for_opened_pull_request.pull_request_name).to eq("Update README.md")
      end
    end

  end

  describe "pull_request_commits_url" do

    context "payload from push event" do
      it "returns pull request number" do
        expect(payload_for_opened_pull_request.pull_request_commits_url).to eq("https://api.github.com/repos/rastasheep/semaphore-flag/pulls/1/commits")
      end
    end

  end

  describe "pull_request_repo" do

    context "payload from push event" do
      it "returns pull request number" do
        expect(payload_for_opened_pull_request.pull_request_repo).to eq("rastasheep/semaphore-flag")
      end
    end

  end

  describe ".extract_action" do

    context "payload from push event" do
      it "returns 'undefined'" do
        expect(payload.send(:extract_action)).to eq("undefined")
      end
    end

    context "payload from pull request" do
      before do
        allow_any_instance_of(RepoHost::Github::Payload).to receive(:extract_commits)
      end

      context "pull request opened" do
        it "returns opened" do
          expect(payload_for_opened_pull_request.send(:extract_action)).to eq("opened")
        end
      end

      context "pull request closed" do
        it "returns opened" do
          expect(payload_for_closed_pull_request.send(:extract_action)).to eq("closed")
        end
      end
    end

  end

  describe ".extract_branch" do

    context "payload from push event" do

      context "normal branch name" do

        it "extracts branch from payload" do
          expect(payload.send(:extract_branch)).to eq("master")
        end

      end

      context "branch name with /" do

        before do
          payload.data["ref"] = "refs/heads/feature/send-file"
        end

        it "extracts branch from payload" do
          expect(payload.send(:extract_branch)).to eq("feature/send-file")
        end

      end

    end

    context "payload from pull request event" do

      it "extracts branch name from pull request payload" do
        expect(payload_for_opened_pull_request.send(:extract_branch)).to eq("pull-request-1")
      end

    end

  end

  describe ".extract_commits" do

    context "forced pushed branch" do

      it "extracts commits from payload" do
        expect(payload_with_forced_pushed_branch.send(:extract_commits)).to eq([JSON.parse(RepoHost::Github::Responses::Payload.post_receive_hook_with_force_pushed_branch)["head_commit"]])
      end

    end

    it "extracts commits from payload" do
      expect(payload.send(:extract_commits)).to eq(JSON.parse(RepoHost::Github::Responses::Payload.post_receive_hook)["commits"])
    end

    context "payload from pull request event" do
      it "calls github api to get pull request commits" do
        expect(payload_for_opened_pull_request.send(:extract_commits)).to be_nil
      end
    end

  end

  describe ".extract_head" do

    it "extracts the head from payload" do
      expect(payload.send(:extract_head)).to eq(JSON.parse(RepoHost::Github::Responses::Payload.post_receive_hook)["after"])
    end

    context "payload from pull request event" do
      it "extracts merge commit" do
        expect(payload_for_opened_pull_request.send(:extract_head)).to eq(JSON.parse(RepoHost::Github::Responses::Payload.post_receive_hook_pull_request)["pull_request"]["head"]["sha"])
      end
    end

  end

  describe ".extract_prev_head" do

    it "extracts the previous head from payload" do
      expect(payload.send(:extract_prev_head)).to eq(JSON.parse(RepoHost::Github::Responses::Payload.post_receive_hook)["before"])
    end

    context "payload from pull request event" do
      it "extracts merge commit" do
        expect(payload_for_opened_pull_request.send(:extract_prev_head)).to eq("0000000000000000000000000000000000000000")
      end
    end

  end

  describe "#branch_created?" do

    context "payload for created branch" do

      it "returns true" do
        expect(payload_for_created_branch.branch_created?).to be_truthy
      end
    end

    context "regular payload" do

      it "returns false" do
        expect(payload.branch_created?).to be_falsey
      end
    end

    context "payload for deleted branch" do

      it "returns false" do
        expect(payload_for_deleted_branch.branch_created?).to be_falsey
      end
    end

    context "payload for created tag" do

      it "returns false" do
        expect(payload_for_created_tag.branch_created?).to be_falsey
      end
    end

    context "payload for pull request" do
      it "returns true" do
        expect(payload_for_opened_pull_request.branch_created?).to be_truthy
      end
    end
  end

  describe "#branch_deleted?" do

    it "returns false" do
      expect(payload.branch_deleted?).to be_falsey
    end

    context "payload for deleted branch" do
      describe "branch_deleted?" do

        it "returns true" do
          expect(payload_for_deleted_branch.branch_deleted?).to be_truthy
        end
      end
    end

    context "payload for pull request" do
      it "returns true" do
        expect(payload_for_closed_pull_request.branch_deleted?).to be_truthy
      end
    end
  end

  describe "#includes_ci_skip?" do

    context "last commit contains [ci skip] in message" do

      it "returns true" do
        expect(payload_with_ci_skip.includes_ci_skip?).to be(true)
      end
    end

    context "last commit contains [skip ci] in message" do

      it "returns true" do
        expect(payload_with_skip_ci.includes_ci_skip?).to be(true)
      end
    end

    context "last commit does not contain [ci skip]" do

      it "returns false" do
        expect(payload.includes_ci_skip?).to be(false)
      end

      context "deleted branch" do

        it "returns false" do
          expect(payload_for_deleted_branch.includes_ci_skip?).to be(false)
        end
      end
    end

    context "payload does not contain commits" do

      it "returns false" do
        expect(payload_without_commits.includes_ci_skip?).to be(false)
      end

    end

    context "payload from pull request" do

      it "returns false" do
        expect(payload_for_opened_pull_request.includes_ci_skip?).to be(false)
      end
    end

  end

  describe "#ref" do
    context "payload from issue comment" do
      it "returns pull request ref" do
        expect(payload_for_issue_comment.ref).to eq("refs/pull/45/merge")
      end
    end
  end
end
