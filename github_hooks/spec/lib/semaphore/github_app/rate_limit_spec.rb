require "spec_helper"

module Semaphore::GithubApp
  RSpec.describe RateLimit do
    let(:floor) { App.collaborators_api_rate_limit }
    let(:resets_at) { Time.zone.at(1_000_000) }

    def client(remaining:, resets_at: nil)
      instance_double(
        RepoHost::Github::Client,
        :rate_limit_remaining => remaining,
        :rate_limit_resets_at => resets_at
      )
    end

    describe ".floor" do
      it "is the reserved-headroom threshold" do
        expect(described_class.floor).to eq(App.collaborators_api_rate_limit)
      end
    end

    describe ".exceeded?" do
      it "is false at or above the floor" do
        expect(described_class.exceeded?(client(:remaining => floor))).to be(false)
        expect(described_class.exceeded?(client(:remaining => floor + 1))).to be(false)
      end

      it "is true below the floor" do
        expect(described_class.exceeded?(client(:remaining => floor - 1))).to be(true)
      end

      it "decides on remaining alone, without reading the reset time" do
        c = instance_double(RepoHost::Github::Client, :rate_limit_remaining => floor - 1)
        expect(c).not_to receive(:rate_limit_resets_at)
        expect(described_class.exceeded?(c)).to be(true)
      end
    end

    describe ".guard!" do
      it "does not raise (or read the reset time) when there is budget" do
        c = instance_double(RepoHost::Github::Client, :rate_limit_remaining => floor)
        expect(c).not_to receive(:rate_limit_resets_at)
        expect { described_class.guard!(c) }.not_to raise_error
      end

      it "raises LowRateLimitError carrying the reset time when below the floor" do
        c = client(:remaining => 0, :resets_at => resets_at)
        expect { described_class.guard!(c) }
          .to raise_error(LowRateLimitError) { |e| expect(e.resets_at).to eq(resets_at) }
      end

      it "still throttles when below the floor even if GitHub reports no reset time" do
        c = client(:remaining => 0, :resets_at => nil)
        expect { described_class.guard!(c) }
          .to raise_error(LowRateLimitError) { |e| expect(e.resets_at).to be_nil }
      end
    end

    describe ".defer_delay" do
      let(:spread) { App.github_app_rate_limit_defer_spread }
      let(:now) { Time.zone.at(1_000_000) }

      it "waits until the reset, then jitters across the spread" do
        future = now + 120
        delays = Array.new(100) { described_class.defer_delay(future, :now => now) }

        expect(delays).to all(be_between(120, 120 + spread))
        expect(delays.max - delays.min).to be > spread / 2 # dispersed across the window
      end

      it "never returns a negative wait when the reset is already past" do
        past = now - 5000
        delays = Array.new(50) { described_class.defer_delay(past, :now => now) }
        expect(delays).to all(be_between(0, spread))
      end

      it "falls back to jitter alone when the reset time is unknown" do
        delays = Array.new(50) { described_class.defer_delay(nil, :now => now) }
        expect(delays).to all(be_between(0, spread))
      end
    end

    describe ".retry_delay" do
      it "defers a rate-limit error until the reset window" do
        now = Time.now
        error = LowRateLimitError.new("low", :resets_at => now + 300)

        delays = Array.new(50) { described_class.retry_delay(3, error) }

        # Always at least the time until reset; never the old exponential curve.
        expect(delays).to all(be >= 300)
      end

      it "keeps the capped exponential backoff for other failures" do
        allow(described_class).to receive(:rand).and_return(0)
        base = App.worker_base_delay
        max = App.worker_max_delay

        expect(described_class.retry_delay(0, StandardError.new)).to eq([base, max].min)
        expect(described_class.retry_delay(2, StandardError.new)).to eq([base * 4, max].min)
        expect(described_class.retry_delay(20, StandardError.new)).to eq(max)
      end
    end
  end
end
