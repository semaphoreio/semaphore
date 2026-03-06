require "spec_helper"
require "sidekiq/api"

module Semaphore::GithubApp
  class Collaborators
    RSpec.describe Worker do
      describe "sidekiq options" do
        it "configures a unique lock keyed by normalized repository slug" do
          options = described_class.get_sidekiq_options

          expect(options["lock"].to_s).to eq("until_executed")
          expect(options["on_conflict"].to_s).to eq("log")
          expect(options["lock_args_method"].to_s).to eq("lock_args")
          expect(options["retry"]).to eq(described_class::MAX_RETRY_ATTEMPTS)
        end
      end

      describe ".lock_args" do
        it "normalizes the repository slug and ignores extra arguments" do
          expect(described_class.lock_args(["Org/Repo", 123_456, 4])).to eq(["org/repo"])
        end

        it "returns an empty lock key for blank slugs" do
          expect(described_class.lock_args(["   "])).to eq([])
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

        it "enqueues only one job for equivalent normalized slugs" do
          described_class.perform_async("Org/Repo", 101)
          described_class.perform_async("org/repo", 202)

          expect(Sidekiq::Queue.new("github_app").size).to eq(1)
        end

        it "enqueues separate jobs for different slugs" do
          described_class.perform_async("org/repo-a")
          described_class.perform_async("org/repo-b")

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
          allow(Semaphore::GithubApp::Collaborators).to receive(:refresh)
            .with("org/repo", 42)
            .and_return(:low_rate_limit, :ok)

          expect { described_class.new.perform("Org/Repo", 42) }.to raise_error(described_class::LowRateLimitError)

          described_class.perform_in(15.minutes, "Org/Repo", 42)
          described_class.perform_in(15.minutes, "org/repo", 43)
          described_class.perform_async("ORG/REPO", 44)

          queue = Sidekiq::Queue.new("github_app")
          scheduled = Sidekiq::ScheduledSet.new
          retry_job = scheduled.find { |job| described_class.lock_args(job.args) == ["org/repo"] }

          expect(queue.size).to eq(0)
          expect(scheduled.size).to eq(1)
          expect(retry_job).not_to be_nil

          expect { described_class.new.perform(*retry_job.args) }.not_to raise_error
          expect(Semaphore::GithubApp::Collaborators).to have_received(:refresh).with("org/repo", 42).twice
        end
      end

      describe ".retry_delay_seconds" do
        it "uses exponential backoff with jitter" do
          allow(Kernel).to receive(:rand).with(0..described_class::RETRY_JITTER_SECONDS).and_return(30)

          expect(described_class.retry_delay_seconds(2)).to eq((described_class::RETRY_BASE_SECONDS * 4) + 30)
        end

        it "caps retry delay at the configured maximum" do
          allow(Kernel).to receive(:rand).with(0..described_class::RETRY_JITTER_SECONDS).and_return(0)

          expect(described_class.retry_delay_seconds(20)).to eq(described_class::RETRY_MAX_SECONDS)
        end
      end

      describe "#perform" do
        let(:slug) { "Org/Repo" }
        let(:remote_id) { 13_609_976 }

        it "normalizes slug and forwards remote_id before refresh" do
          allow(Semaphore::GithubApp::Collaborators).to receive(:refresh).with("org/repo", remote_id).and_return(:ok)

          described_class.new.perform(slug, remote_id)

          expect(Semaphore::GithubApp::Collaborators).to have_received(:refresh).with("org/repo", remote_id)
        end

        it "raises an error on low rate limit so Sidekiq can retry with backoff" do
          allow(Semaphore::GithubApp::Collaborators).to receive(:refresh).with("org/repo", remote_id).and_return(:low_rate_limit)

          expect { described_class.new.perform(slug, remote_id) }.to raise_error(described_class::LowRateLimitError)
        end

        it "logs unexpected results without raising" do
          allow(Semaphore::GithubApp::Collaborators).to receive(:refresh).with("org/repo", remote_id).and_return(:unknown)
          allow(Rails.logger).to receive(:info)

          described_class.new.perform(slug, remote_id)

          expect(Rails.logger).to have_received(:info).with(include("Unknown result: :unknown"))
        end
      end
    end
  end
end
