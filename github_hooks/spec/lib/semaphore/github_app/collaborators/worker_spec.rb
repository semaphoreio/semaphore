require "spec_helper"
require "sidekiq_unique_jobs/testing"

module Semaphore::GithubApp
  RSpec.describe Collaborators::Worker do
    let(:slug) { "org/my-repo" }
    let(:remote_id) { 12345 }

    describe "sidekiq_options" do
      it "uses the github_app queue" do
        expect(described_class.get_sidekiq_options["queue"]).to eq(:github_app)
      end

      it "uses until_expired lock" do
        expect(described_class.get_sidekiq_options["lock"]).to eq(:until_expired)
      end

      it "rejects conflicting jobs" do
        expect(described_class.get_sidekiq_options["on_conflict"]).to eq({ "client" => :log, "server" => :reject })
      end

      it "has a lock_ttl matching App.worker_lock_ttl" do
        expect(described_class.get_sidekiq_options["lock_ttl"]).to eq(App.worker_lock_ttl)
      end

      it "has a max retry count matching App.worker_max_retries" do
        expect(described_class.get_sidekiq_options["retry"]).to eq(App.worker_max_retries)
      end

      it "has valid sidekiq-unique-jobs configuration" do
        expect(described_class).to have_valid_sidekiq_options
      end
    end

    describe "lock_args" do
      it "uses only the slug for uniqueness (ignores remote_id)" do
        lock_args_method = described_class.get_sidekiq_options["lock_args_method"]
        result = lock_args_method.call([slug, remote_id])

        expect(result).to eq([slug])
      end
    end

    describe "#perform" do
      it "calls Collaborators.refresh and logs Finish on success" do
        allow(Collaborators).to receive(:refresh).with(slug, remote_id).and_return(:ok)

        expect(Rails.logger).to receive(:info).with(/#{slug}: Start/)
        expect(Rails.logger).to receive(:info).with(/#{slug}: Finish/)

        described_class.new.perform(slug, remote_id)
      end

      it "returns early for blank slug" do
        expect(Collaborators).not_to receive(:refresh)
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/: Empty/)

        described_class.new.perform("", nil)
      end

      it "logs 'Token not found' when result is :no_token" do
        allow(Collaborators).to receive(:refresh).and_return(:no_token)
        expect(Rails.logger).to receive(:info).with(/Start/)
        expect(Rails.logger).to receive(:info).with(/Token not found/)

        described_class.new.perform(slug, remote_id)
      end

      it "logs 'Repository not found' when result is :no_repository" do
        allow(Collaborators).to receive(:refresh).and_return(:no_repository)
        expect(Rails.logger).to receive(:info).with(/Start/)
        expect(Rails.logger).to receive(:info).with(/Repository not found/)

        described_class.new.perform(slug, remote_id)
      end

      it "raises LowRateLimitError when result is :low_rate_limit" do
        allow(Collaborators).to receive(:refresh).and_return(:low_rate_limit)

        expect do
          described_class.new.perform(slug, remote_id)
        end.to raise_error(LowRateLimitError, /rate limit too low/i)
      end
    end

    describe "sidekiq_retries_exhausted" do
      it "logs an error and releases the unique lock" do
        job = { "args" => [slug, remote_id], "class" => described_class.to_s }
        exception = LowRateLimitError.new("rate limit too low")

        expect(Rails.logger).to receive(:error).with(/#{slug}: Retries exhausted.*LowRateLimitError/)

        worker_instance = instance_double(described_class)
        allow(described_class).to receive(:new).and_return(worker_instance)
        expect(worker_instance).to receive(:delete_unique_lock).with([slug])

        described_class.sidekiq_retries_exhausted_block.call(job, exception)
      end
    end

    describe "exponential backoff" do
      it "computes increasing delays based on retry count" do
        retry_block = described_class.sidekiq_retry_in_block
        base = App.worker_base_delay
        max_delay = App.worker_max_delay

        allow_any_instance_of(Object).to receive(:rand).and_return(0)

        delays = (0..4).map { |count| retry_block.call(count, StandardError.new, {}) }

        expected = [
          base * 1,  # attempt 0
          base * 2,  # attempt 1
          base * 4,  # attempt 2
          base * 8,  # attempt 3
          base * 16  # attempt 4
        ].map { |d| [d, max_delay].min }

        expect(delays).to eq(expected)
      end

      it "adds jitter to the delay" do
        retry_block = described_class.sidekiq_retry_in_block
        base = App.worker_base_delay
        jitter_max = App.worker_jitter_max

        delays = Array.new(50) { retry_block.call(0, StandardError.new, {}) }

        expect(delays).to all(be_between(base, base + jitter_max))
        expect(delays.uniq.size).to be > 1
      end

      it "caps delay at App.worker_max_delay" do
        retry_block = described_class.sidekiq_retry_in_block
        max_delay = App.worker_max_delay

        allow_any_instance_of(Object).to receive(:rand).and_return(0)

        # Use a high retry count that would exceed max_delay without the cap
        high_count_delay = retry_block.call(20, StandardError.new, {})

        expect(high_count_delay).to eq(max_delay)
      end
    end

    describe "job uniqueness", :multithreaded do
      before do
        Sidekiq::Testing.disable!
        SidekiqUniqueJobs.use_config(enabled: true) do
          # ensure clean state
        end
      end

      after do
        Sidekiq::Testing.fake!
      end

      it "allows enqueueing a job for a new slug" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          jid = described_class.perform_async(slug, remote_id)

          expect(jid).not_to be_nil
        end
      end

      it "rejects a duplicate job for the same slug" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          first_jid = described_class.perform_async(slug, remote_id)
          second_jid = described_class.perform_async(slug, remote_id)

          expect(first_jid).not_to be_nil
          expect(second_jid).to be_nil
        end
      end

      it "rejects a duplicate even when remote_id differs (lock_args uses slug only)" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          first_jid = described_class.perform_async(slug, 111)
          second_jid = described_class.perform_async(slug, 222)

          expect(first_jid).not_to be_nil
          expect(second_jid).to be_nil
        end
      end

      it "allows jobs for different slugs" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          first_jid = described_class.perform_async("org/repo-a", remote_id)
          second_jid = described_class.perform_async("org/repo-b", remote_id)

          expect(first_jid).not_to be_nil
          expect(second_jid).not_to be_nil
        end
      end

      it "rejects a duplicate scheduled job for the same slug" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          first_jid = described_class.perform_in(10, slug, remote_id)
          second_jid = described_class.perform_in(20, slug, remote_id)

          expect(first_jid).not_to be_nil
          expect(second_jid).to be_nil
        end
      end

      it "rejects enqueueing when a scheduled job already exists for the same slug" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          scheduled_jid = described_class.perform_in(10.minutes, slug, remote_id)
          async_jid = described_class.perform_async(slug, remote_id)

          expect(scheduled_jid).not_to be_nil
          expect(async_jid).to be_nil
        end
      end
    end

    describe "retry lifecycle with lock persistence", :multithreaded do
      before do
        Sidekiq::Testing.disable!
      end

      after do
        Sidekiq::Testing.fake!
      end

      it "enqueue -> fail (rate limit) -> reject duplicate -> retry succeeds" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          allow(Rails.logger).to receive(:info)

          # 1. Job is enqueued
          jid = described_class.perform_async(slug, remote_id)
          expect(jid).not_to be_nil

          # Retrieve the job item from the queue for middleware processing
          item = Sidekiq::Queue.new("github_app").first.item

          # 2. Job fails because of rate limit — lock is NOT released
          allow(Collaborators).to receive(:refresh).and_return(:low_rate_limit)

          middleware = SidekiqUniqueJobs::Middleware::Server.new
          expect do
            middleware.call(described_class.new, item, "github_app") do
              described_class.new.perform(slug, remote_id)
            end
          end.to raise_error(LowRateLimitError)

          # 3. Another job with same slug tries to enqueue — rejected
          dup_jid = described_class.perform_async(slug, remote_id)
          expect(dup_jid).to be_nil

          # 4. Failed job is retried and now passes — lock is released
          allow(Collaborators).to receive(:refresh).and_return(:ok)

          middleware.call(described_class.new, item, "github_app") do
            described_class.new.perform(slug, remote_id)
          end

          # New job can now be enqueued for the same slug
          new_jid = described_class.perform_async(slug, remote_id)
          expect(new_jid).not_to be_nil
        end
      end
    end

    describe "lock release on terminal results", :multithreaded do
      before do
        Sidekiq::Testing.disable!
      end

      after do
        Sidekiq::Testing.fake!
      end

      it "releases lock after :no_token so new jobs can be enqueued" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          allow(Rails.logger).to receive(:info)
          allow(Collaborators).to receive(:refresh).and_return(:no_token)

          jid = described_class.perform_async(slug, remote_id)
          expect(jid).not_to be_nil

          item = Sidekiq::Queue.new("github_app").first.item
          middleware = SidekiqUniqueJobs::Middleware::Server.new

          middleware.call(described_class.new, item, "github_app") do
            described_class.new.perform(slug, remote_id)
          end

          new_jid = described_class.perform_async(slug, remote_id)
          expect(new_jid).not_to be_nil
        end
      end

      it "releases lock after :no_repository so new jobs can be enqueued" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          allow(Rails.logger).to receive(:info)
          allow(Collaborators).to receive(:refresh).and_return(:no_repository)

          jid = described_class.perform_async(slug, remote_id)
          expect(jid).not_to be_nil

          item = Sidekiq::Queue.new("github_app").first.item
          middleware = SidekiqUniqueJobs::Middleware::Server.new

          middleware.call(described_class.new, item, "github_app") do
            described_class.new.perform(slug, remote_id)
          end

          new_jid = described_class.perform_async(slug, remote_id)
          expect(new_jid).not_to be_nil
        end
      end

      it "releases lock after unknown result so new jobs can be enqueued" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          allow(Rails.logger).to receive(:info)
          allow(Collaborators).to receive(:refresh).and_return(:unexpected_result)

          jid = described_class.perform_async(slug, remote_id)
          expect(jid).not_to be_nil

          item = Sidekiq::Queue.new("github_app").first.item
          middleware = SidekiqUniqueJobs::Middleware::Server.new

          middleware.call(described_class.new, item, "github_app") do
            described_class.new.perform(slug, remote_id)
          end

          new_jid = described_class.perform_async(slug, remote_id)
          expect(new_jid).not_to be_nil
        end
      end

      it "does NOT release lock after :low_rate_limit (job will retry)" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          allow(Rails.logger).to receive(:info)
          allow(Collaborators).to receive(:refresh).and_return(:low_rate_limit)

          jid = described_class.perform_async(slug, remote_id)
          expect(jid).not_to be_nil

          item = Sidekiq::Queue.new("github_app").first.item
          middleware = SidekiqUniqueJobs::Middleware::Server.new

          expect do
            middleware.call(described_class.new, item, "github_app") do
              described_class.new.perform(slug, remote_id)
            end
          end.to raise_error(LowRateLimitError)

          dup_jid = described_class.perform_async(slug, remote_id)
          expect(dup_jid).to be_nil
        end
      end
    end
  end
end
