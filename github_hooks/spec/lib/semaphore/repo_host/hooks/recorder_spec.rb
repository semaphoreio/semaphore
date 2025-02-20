require "spec_helper"

RSpec.describe Semaphore::RepoHost::Hooks::Recorder do
  before do
    @project = FactoryBot.create(:project)
  end

  let(:payload) { RepoHost::Github::Responses::Payload.post_receive_hook_pull_request_within_repo }
  let(:params) { { :hash_id => @project.id, :example => "content", :payload => payload } }

  describe ".create_post_commit_request" do

    it "creates a new GithubPostCommitRequest with given params" do
      post_commit_request = Semaphore::RepoHost::Hooks::Recorder.create_post_commit_request(params, @project)

      expect(post_commit_request.request).to eql("hash_id" => @project.id, "example" => "content", "payload" => payload)
    end
  end

  describe ".set_commit_sha" do

    context "given a post_commit_request with push payload" do
      let(:payload) { RepoHost::Github::Responses::Payload.webhook_json }

      it "updates commit_sha column on workflow" do
        @post_commit_request = Semaphore::RepoHost::Hooks::Recorder.create_post_commit_request(params, @project)
        Semaphore::RepoHost::Hooks::Recorder.set_commit_sha(@post_commit_request)

        expect(@post_commit_request.reload.commit_sha).to eql("f204bcfa19af28bdaa1aab0550caf8a79641e9ab")
      end
    end
  end

  describe ".set_git_ref" do

    context "given a post_commit_request with push payload" do
      let(:payload) { RepoHost::Github::Responses::Payload.webhook_json }

      it "updates git_ref column on workflow" do
        @post_commit_request = Semaphore::RepoHost::Hooks::Recorder.create_post_commit_request(params, @project)
        Semaphore::RepoHost::Hooks::Recorder.set_git_ref(@post_commit_request)

        expect(@post_commit_request.reload.git_ref).to eql("refs/heads/master")
      end
    end
  end

  describe ".record_hook" do
    let(:payload) { double("Payload", :super_encode_to_utf8 => "encoded payload") }
    let(:params) { { :hash_id => @project.id, :example => "content", :payload => payload } }

    it "encodes params' payload" do
      expect(Semaphore::RepoHost::Hooks::Recorder).to receive(:create_post_commit_request).with(
        { :hash_id => @project.id, :example => "content", :payload => "encoded payload" }, @project
      )

      Semaphore::RepoHost::Hooks::Recorder.record_hook(params, @project)
    end

    it "creates a new post commit record" do
      expect do
        Semaphore::RepoHost::Hooks::Recorder.record_hook(params, @project)
      end.to change(Workflow, :count).by(1)
    end

    it "connects it to a project (if it exists)" do
      expect do
        Semaphore::RepoHost::Hooks::Recorder.record_hook(params, @project)
      end.to change(@project.workflows, :count).by(1)
    end
  end

end
