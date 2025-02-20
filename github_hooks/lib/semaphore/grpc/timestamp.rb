module Semaphore
  module Grpc
    module Timestamp
      module_function

      def grpc_timestamp(timestamp)
        if timestamp
          ::Google::Protobuf::Timestamp.new(:seconds => timestamp.to_i)
        end
      end
    end
  end
end
