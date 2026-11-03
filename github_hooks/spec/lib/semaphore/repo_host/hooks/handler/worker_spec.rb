require "spec_helper"

RSpec.describe Semaphore::RepoHost::Hooks::Handler::Worker do
  before do
    @project = FactoryBot.create(:project)
    @post_commit_request = FactoryBot.create(:workflow, :project => @project)
  end

  describe "#perform" do
    it "processes the request" do
      expect(Semaphore::RepoHost::Hooks::Handler).to receive(:run) do |request|
        expect(request).to eq(@post_commit_request)
      end

      described_class.new.perform(@post_commit_request.id)
    end

    it "passes the retry and stale merge commit attempt counts through" do
      expect(Semaphore::RepoHost::Hooks::Handler).to receive(:run).with(@post_commit_request, anything, "payload", "signature", 2, 1)

      described_class.new.perform(@post_commit_request.id, "payload", "signature", 2, 1)
    end
  end

  describe "when Sidekiq retries are exhausted" do
    it "releases an approval claim the failed job held" do
      @post_commit_request.update(:state => Workflow::STATE_PR_APPROVAL_IN_PROGRESS)

      described_class.sidekiq_retries_exhausted_block.call({ "args" => [@post_commit_request.id] }, StandardError.new)

      expect(@post_commit_request.reload.state).to eq(Workflow::STATE_SKIP_FILTERED_CONTRIBUTOR)
    end

    it "leaves other workflows alone" do
      @post_commit_request.update(:state => Workflow::STATE_LAUNCHING)

      described_class.sidekiq_retries_exhausted_block.call({ "args" => [@post_commit_request.id] }, StandardError.new)

      expect(@post_commit_request.reload.state).to eq(Workflow::STATE_LAUNCHING)
    end
  end
end
