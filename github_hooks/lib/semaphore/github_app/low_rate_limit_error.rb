module Semaphore::GithubApp
  class LowRateLimitError < StandardError
    # Time the throttled GitHub REST bucket refills, used to defer the Sidekiq
    # retry until budget actually returns. nil when GitHub didn't report it.
    attr_reader :resets_at

    def initialize(message = nil, resets_at: nil)
      super(message)
      @resets_at = resets_at
    end
  end
end
