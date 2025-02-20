require "spec_helper"

RSpec.describe Semaphore::RepoHost::WebhookFilter do
  let(:returned_filter) { Semaphore::RepoHost::WebhookFilter.create_webhook_filter(request, "") }
  let(:request)         { double("Request", :bitbucket_v1? => false, :bitbucket_v2? => false, :github? => false) }

  context "when request is from GitHub" do
    it "returns GitHub webhook filter" do
      allow(request).to receive(:github?).and_return(true)
      expect(returned_filter).to be_a Semaphore::RepoHost::Github::WebhookFilter
    end
  end
end
