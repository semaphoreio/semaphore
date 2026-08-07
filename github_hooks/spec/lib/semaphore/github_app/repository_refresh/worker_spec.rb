require "spec_helper"
require "sidekiq_unique_jobs/testing"

module Semaphore::GithubApp
  RSpec.describe RepositoryRefresh::Worker, :aggregate_failures do
    let(:installation_id) { 98765 }
    let(:slug) { "renderedtext/brand-new-repo" }

    describe "sidekiq_options" do
      it "uses the github_app queue with an until_expired lock that rejects conflicts" do
        options = described_class.get_sidekiq_options

        expect(options["queue"]).to eq(:github_app)
        expect(options["lock"]).to eq(:until_expired)
        expect(options["on_conflict"]).to eq({ "client" => :log, "server" => :reject })
        expect(options["lock_ttl"]).to eq(App.worker_lock_ttl)
        expect(options["retry"]).to eq(App.worker_max_retries)
      end

      it "has valid sidekiq-unique-jobs configuration" do
        expect(described_class).to have_valid_sidekiq_options
      end
    end

    describe "#perform" do
      it "delegates to RepositoryRefresh.fetch_and_cache_repository and logs Finish on success" do
        allow(RepositoryRefresh).to receive(:fetch_and_cache_repository).with(installation_id, slug).and_return(:ok)

        expect(Rails.logger).to receive(:info).with(%r{#{installation_id}/#{slug}: Start})
        expect(Rails.logger).to receive(:info).with(%r{#{installation_id}/#{slug}: Finish})

        described_class.new.perform(installation_id, slug)
      end

      it "returns early without calling GitHub when the slug is blank" do
        expect(RepositoryRefresh).not_to receive(:fetch_and_cache_repository)
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(installation_id, "")

        expect(Rails.logger).to have_received(:info).with(/Empty slug/)
      end

      it "logs 'Token not found' when result is :no_token" do
        allow(RepositoryRefresh).to receive(:fetch_and_cache_repository).and_return(:no_token)

        expect(Rails.logger).to receive(:info).with(/Start/)
        expect(Rails.logger).to receive(:info).with(/Token not found/)

        described_class.new.perform(installation_id, slug)
      end

      it "logs 'not accessible' when result is :no_repository" do
        allow(RepositoryRefresh).to receive(:fetch_and_cache_repository).and_return(:no_repository)

        expect(Rails.logger).to receive(:info).with(/Start/)
        expect(Rails.logger).to receive(:info).with(/not accessible/)

        described_class.new.perform(installation_id, slug)
      end

      it "raises LowRateLimitError when result is :low_rate_limit" do
        allow(RepositoryRefresh).to receive(:fetch_and_cache_repository).and_return(:low_rate_limit)

        expect do
          described_class.new.perform(installation_id, slug)
        end.to raise_error(LowRateLimitError, /rate limit too low/i)
      end

      it "treats a non-rate-limit error as terminal: releases the lock and does not retry" do
        allow(RepositoryRefresh).to receive(:fetch_and_cache_repository).and_raise(StandardError.new("revoked token"))
        allow(Rails.logger).to receive(:info)

        worker = described_class.new
        expect(worker).to receive(:delete_unique_lock).with([installation_id, slug])

        expect { worker.perform(installation_id, slug) }.not_to raise_error
        expect(Rails.logger).to have_received(:info).with(/Terminal error/)
      end

      it "re-raises a transient GitHub error so Sidekiq retries, keeping the lock" do
        allow(RepositoryRefresh).to receive(:fetch_and_cache_repository)
          .and_raise(RepoHost::RemoteException::ServiceUnavailable.new("503"))
        allow(Rails.logger).to receive(:info)

        worker = described_class.new
        expect(worker).not_to receive(:delete_unique_lock)

        expect { worker.perform(installation_id, slug) }
          .to raise_error(RepoHost::RemoteException::ServiceUnavailable)
        expect(Rails.logger).to have_received(:info).with(/Transient error — retrying with backoff/)
      end

      it "re-raises a transient DB error (StatementInvalid) so Sidekiq retries" do
        allow(RepositoryRefresh).to receive(:fetch_and_cache_repository)
          .and_raise(ActiveRecord::StatementInvalid.new("connection timed out"))
        allow(Rails.logger).to receive(:info)

        worker = described_class.new
        expect(worker).not_to receive(:delete_unique_lock)

        expect { worker.perform(installation_id, slug) }
          .to raise_error(ActiveRecord::StatementInvalid)
        expect(Rails.logger).to have_received(:info).with(/Transient error — retrying with backoff/)
      end

      it "releases the lock for the blank-slug no-op" do
        allow(Rails.logger).to receive(:info)

        worker = described_class.new
        expect(worker).to receive(:delete_unique_lock).with([installation_id, ""])

        worker.perform(installation_id, "")
      end
    end

    describe "sidekiq_retries_exhausted" do
      it "logs an error and releases the unique lock for the installation/slug pair" do
        job = { "args" => [installation_id, slug], "class" => described_class.to_s }
        exception = LowRateLimitError.new("rate limit too low")

        expect(Rails.logger).to receive(:error).with(%r{#{installation_id}/#{slug}: Retries exhausted.*LowRateLimitError})

        worker_instance = instance_double(described_class)
        allow(described_class).to receive(:new).and_return(worker_instance)
        expect(worker_instance).to receive(:delete_unique_lock).with([installation_id, slug])

        described_class.sidekiq_retries_exhausted_block.call(job, exception)
      end
    end

    describe "job uniqueness", :multithreaded do
      before { Sidekiq::Testing.disable! }
      after { Sidekiq::Testing.fake! }

      it "rejects a duplicate job for the same installation/slug pair" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          first_jid = described_class.perform_async(installation_id, slug)
          second_jid = described_class.perform_async(installation_id, slug)

          expect(first_jid).not_to be_nil
          expect(second_jid).to be_nil
        end
      end

      it "allows concurrent jobs for different repositories in the same installation" do
        SidekiqUniqueJobs.use_config(enabled: true) do
          first_jid = described_class.perform_async(installation_id, "renderedtext/one")
          second_jid = described_class.perform_async(installation_id, "renderedtext/two")

          expect(first_jid).not_to be_nil
          expect(second_jid).not_to be_nil
        end
      end
    end
  end
end
