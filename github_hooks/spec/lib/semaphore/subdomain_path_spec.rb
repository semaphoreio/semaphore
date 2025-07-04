require "spec_helper"

RSpec.describe Semaphore::SubdomainPath do
  before do
    allow(App).to receive(:base_url).and_return("https://id.semaphoreci.com")
  end

  describe "#call" do
    it "changes the subdomain" do
      expect(described_class.new.call("me")).to eql("https://me.semaphoreci.com")
    end

    it "inject the path" do
      expect(described_class.new.call("me", "/foo")).to eql("https://me.semaphoreci.com/foo")
    end

    it "inject the query" do
      expect(described_class.new.call("me", "/foo", "coo=3")).to eql("https://me.semaphoreci.com/foo?coo=3")
    end
  end

  describe "#ensure_safe_url" do

    it "returns safe_url if provided one is on different host" do
      expect(described_class.new.ensure_safe_url("https://example.com", "safe_url")).to eql("safe_url")
    end

    it "returns url if it is on the same host" do
      expect(described_class.new.ensure_safe_url("https://foo.semaphoreci.com", "safe_url")).to eql("https://foo.semaphoreci.com")
    end

    it "adds s to http urls" do
      expect(described_class.new.ensure_safe_url("http://foo.semaphoreci.com", "safe_url")).to eql("https://foo.semaphoreci.com")
    end

    it "require schema in the url" do
      expect(described_class.new.ensure_safe_url("foo.semaphoreci.com", "safe_url")).to eql("safe_url")
    end

  end
end
