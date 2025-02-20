require "spec_helper"

module Semaphore
  module RepoHost
    RSpec.describe NoPassFilter do
      describe "#unsupported_webhook?" do
        it "returns true" do
          filter = described_class.new(nil, nil)
          expect(filter.unsupported_webhook?).to eql(true)
        end
      end
    end
  end
end
