require "spec_helper"

RSpec.describe Semaphore::GuardUserClient, :aggregate_failures do
  describe ".refresh_repository_provider" do
    let(:stub) { instance_double(InternalApi::User::UserService::Stub) }
    let(:user_id) { SecureRandom.uuid }

    before do
      allow(described_class).to receive(:stub).and_return(stub)
      allow(stub).to receive(:refresh_repository_provider)
    end

    it "asks guard to refresh the user's provider within the timeout" do
      described_class.refresh_repository_provider(user_id, :GITHUB)

      expect(stub).to have_received(:refresh_repository_provider) do |request, opts|
        expect(request.user_id).to eq(user_id)
        expect(request.type).to eq(:GITHUB)
        expect(opts[:deadline]).to be_within(1).of(Time.now.utc + described_class::TIMEOUT)
      end
    end
  end
end
