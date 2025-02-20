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
  end
end
