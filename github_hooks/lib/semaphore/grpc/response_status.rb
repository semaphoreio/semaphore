module Semaphore
  module Grpc
    module ResponseStatus
      def grpc_status_ok(message = nil)
        grpc_status(InternalApi::ResponseStatus::Code::OK, message)
      end

      def grpc_status_bad_param(message = nil)
        grpc_status(InternalApi::ResponseStatus::Code::BAD_PARAM, message)
      end

      def grpc_status(code, message = nil)
        attributes = { :code => code }.tap { |attr|
          attr.merge!(:message => message) if message
        }

        InternalApi::ResponseStatus.new(attributes)
      end
    end
  end
end
