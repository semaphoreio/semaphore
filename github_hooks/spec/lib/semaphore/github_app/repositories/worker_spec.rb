require "spec_helper"
require "sidekiq/api"

module Semaphore::GithubApp
  class Repositories
    RSpec.describe Worker do
      describe "sidekiq options" do
        it "configures a unique lock keyed by installation id" do
          options = described_class.get_sidekiq_options

          expect(options["lock"].to_s).to eq("until_executed")
          expect(options["on_conflict"].to_s).to eq("log")
          expect(options["lock_args_method"].to_s).to eq("lock_args")
          expect(options["retry"]).to eq(described_class::MAX_RETRY_ATTEMPTS)
        end
      end

      describe ".lock_args" do
        it "normalizes installation id" do
          expect(described_class.lock_args(["42"])).to eq([42])
        end
      end

      describe ".perform_async queue uniqueness" do
        around do |example|
          Sidekiq::Testing.disable! do
            Sidekiq::Queue.new("github_app").clear
            example.run
          ensure
            Sidekiq::Queue.new("github_app").clear
          end
        end

        it "enqueues only one job for equivalent installation ids" do
          described_class.perform_async("42")
          described_class.perform_async(42)

          expect(Sidekiq::Queue.new("github_app").size).to eq(1)
        end

        it "enqueues separate jobs for different installation ids" do
          described_class.perform_async(42)
          described_class.perform_async(43)

          expect(Sidekiq::Queue.new("github_app").size).to eq(2)
        end
      end

      describe "rate-limit retry queue deduplication" do
        around do |example|
          Sidekiq::Testing.disable! do
            Sidekiq::Queue.new("github_app").clear
            Sidekiq::ScheduledSet.new.clear
            example.run
          ensure
            Sidekiq::Queue.new("github_app").clear
            Sidekiq::ScheduledSet.new.clear
          end
        end

        it "keeps one pending retry and succeeds when rate limit recovers" do
          allow(Semaphore::GithubApp::Repositories).to receive(:refresh).with(42).and_return(:low_rate_limit, :ok)

          expect { described_class.new.perform(42) }.to raise_error(described_class::LowRateLimitError)

          described_class.perform_in(15.minutes, 42)
          described_class.perform_in(15.minutes, "42")
          described_class.perform_async(42)

          queue = Sidekiq::Queue.new("github_app")
          scheduled = Sidekiq::ScheduledSet.new
          retry_job = scheduled.find { |job| described_class.lock_args(job.args) == [42] }

          expect(queue.size).to eq(0)
          expect(scheduled.size).to eq(1)
          expect(retry_job).not_to be_nil

          expect { described_class.new.perform(*retry_job.args) }.not_to raise_error
          expect(Semaphore::GithubApp::Repositories).to have_received(:refresh).with(42).twice
        end
      end

      describe ".retry_delay_seconds" do
        it "uses exponential backoff with jitter" do
          allow(Kernel).to receive(:rand).with(0..described_class::RETRY_JITTER_SECONDS).and_return(45)

          expect(described_class.retry_delay_seconds(1)).to eq((described_class::RETRY_BASE_SECONDS * 2) + 45)
        end
      end

      describe "#perform" do
        let(:installation_id) { "13609976" }

        it "normalizes installation id before refresh" do
          allow(Semaphore::GithubApp::Repositories).to receive(:refresh).with(13_609_976).and_return(:ok)

          described_class.new.perform(installation_id)

          expect(Semaphore::GithubApp::Repositories).to have_received(:refresh).with(13_609_976)
        end

        it "raises an error on low rate limit so Sidekiq can retry with backoff" do
          allow(Semaphore::GithubApp::Repositories).to receive(:refresh).with(13_609_976).and_return(:low_rate_limit)

          expect { described_class.new.perform(installation_id) }.to raise_error(described_class::LowRateLimitError)
        end

        it "logs unexpected results without raising" do
          allow(Semaphore::GithubApp::Repositories).to receive(:refresh).with(13_609_976).and_return(:unknown)
          allow(Rails.logger).to receive(:info)

          described_class.new.perform(installation_id)

          expect(Rails.logger).to have_received(:info).with(include("Unknown result: :unknown"))
        end
      end
    end
  end
end
