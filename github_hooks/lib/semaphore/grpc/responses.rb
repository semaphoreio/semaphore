module Semaphore
  module Grpc
    module Responses
      def not_found(name, id)
        raise ::GRPC::NotFound.new("#{name.capitalize} #{id} not found.")
      end

      def not_authorized(name, id)
        not_found(name, id)
      end
    end
  end
end
