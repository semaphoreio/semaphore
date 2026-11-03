require "spec_helper"

RSpec.describe Semaphore::RepoHost::Hooks::GithubCache, :aggregate_failures do
  it "reads back what it wrote" do
    expect(described_class.write("key", { "sha" => "abc" }, :ttl => 60)).to be(true)

    expect(described_class.read("key")).to eq({ "sha" => "abc" })
  end

  it "misses an unknown key" do
    expect(described_class.read("missing")).to be_nil
  end

  it "expires entries after their ttl" do
    described_class.write("key", ["abc"], :ttl => 60)

    ttl = RedisClient.new(:url => App.redis_sidekiq_url).call("TTL", "#{described_class::KEY_PREFIX}:key")

    expect(ttl).to be_between(1, 60)
  end

  it "keeps the first value when writing only new keys" do
    described_class.write("key", "first", :ttl => 60, :only_new => true)

    expect(described_class.write("key", "second", :ttl => 60, :only_new => true)).to be(false)
    expect(described_class.read("key")).to eq("first")
  end

  it "grants a lock to one holder and releases it only with its token" do
    token = described_class.lock("lock", :ttl => 30)

    expect(token).to be_present
    expect(described_class.lock("lock", :ttl => 30)).to be_nil

    described_class.unlock("lock", "other-token")
    expect(described_class.exists?("lock")).to be(true)

    described_class.unlock("lock", token)
    expect(described_class.exists?("lock")).to be(false)
  end

  it "fails open and counts the error when Redis is unavailable" do
    allow(described_class).to receive(:call).and_raise(RedisClient::CannotConnectError)
    allow(Watchman).to receive(:increment)

    expect(described_class.read("key")).to be_nil
    expect(described_class.write("key", "value", :ttl => 60)).to be(false)
    expect(described_class.lock("lock", :ttl => 30)).to be_nil
    expect(described_class.exists?("lock")).to be(false)
    expect(Watchman).to have_received(:increment).with("github_hooks.shared_cache.error", :tags => ["read"])
  end

  it "logs repeated errors once per interval while counting each" do
    allow(described_class).to receive(:call).and_raise(RedisClient::CannotConnectError)
    allow(Watchman).to receive(:increment)
    allow(Rails.logger).to receive(:warn)
    described_class.instance_variable_set(:@error_logged_at, nil)

    3.times { described_class.read("key") }

    expect(Watchman).to have_received(:increment).with("github_hooks.shared_cache.error", :tags => ["read"]).exactly(3).times
    expect(Rails.logger).to have_received(:warn).once
  end

  it "builds one connection pool when threads start together" do
    pool = described_class.send(:pool)
    described_class.instance_variable_set(:@pool, nil)
    allow(RedisClient).to receive(:config).and_wrap_original do |original, **options|
      sleep(0.01)
      original.call(**options)
    end

    pools = Array.new(5) { Thread.new { described_class.send(:pool) } }.map(&:value)

    expect(pools.uniq.size).to eq(1)
    expect(RedisClient).to have_received(:config).once
  ensure
    described_class.instance_variable_set(:@pool, pool)
  end

  it "does nothing when disabled" do
    allow(App).to receive(:github_shared_cache_enabled).and_return(false)
    allow(described_class).to receive(:call)

    expect(described_class.write("key", "value", :ttl => 60)).to be(false)
    expect(described_class.read("key")).to be_nil
    expect(described_class.lock("lock", :ttl => 30)).to be_nil
    expect(described_class).not_to have_received(:call)
  end
end
