module Semaphore
  class SkipCi
    def call(message)
      message.include?("[ci skip]") || message.include?("[skip ci]")
    end
  end
end
