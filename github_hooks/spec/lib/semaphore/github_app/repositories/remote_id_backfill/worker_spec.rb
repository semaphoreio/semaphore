require "spec_helper"

module Semaphore::GithubApp
  class Repositories
    class RemoteIdBackfill
      RSpec.describe Worker do
        describe "#perform" do
          it "processes result without auto-enqueuing another worker" do
            allow(Semaphore::GithubApp::Repositories::RemoteIdBackfill).to receive(:refresh_next_installation).and_return(
              {
                :status => :ok,
                :installation_id => 123,
                :updated_count => 10,
                :remaining_installations => true
              }
            )
            expect(described_class).not_to receive(:perform_async)

            described_class.new.perform
          end

          it "retries the same installation on low rate limit" do
            allow(Semaphore::GithubApp::Repositories::RemoteIdBackfill).to receive(:refresh_installation).with(123).and_return(
              {
                :status => :low_rate_limit,
                :installation_id => 123
              }
            )
            expect(described_class).to receive(:perform_in).with(15.minutes, 123)

            described_class.new.perform(123)
          end
        end
      end
    end
  end
end
