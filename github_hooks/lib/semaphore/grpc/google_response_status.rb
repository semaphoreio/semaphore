module Semaphore
  module Grpc
    module GoogleResponseStatus

      def google_status_bad_param(message = nil)
        ::Google::Rpc::Status.new(
          :code => ::Google::Rpc::Code::INVALID_ARGUMENT,
          :message => message
        )
      end

      def google_status_ok
        ::Google::Rpc::Status.new(
          :code => ::Google::Rpc::Code::OK
        )
      end

      def google_status_failed(message = nil)
        ::Google::Rpc::Status.new(
          :code => ::Google::Rpc::Code::INTERNAL,
          :message => message
        )
      end

      def google_status_failed_precondition(message = nil)
        ::Google::Rpc::Status.new(
          :code => ::Google::Rpc::Code::FAILED_PRECONDITION,
          :message => message
        )
      end

    end
  end
end
