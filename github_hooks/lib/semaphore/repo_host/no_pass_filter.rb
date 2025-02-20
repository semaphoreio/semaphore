module Semaphore
  module RepoHost
    class NoPassFilter
      def initialize(_, _)
      end

      def unsupported_webhook?
        true
      end

      def member_webhook?
        false
      end
    end
  end
end
