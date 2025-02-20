module Semaphore
  module Grpc
    module Dsl

      #
      # The GprcDSL is a handy way to create safe and monitored RCP implementations.
      #
      # When RPC calls are implemented with the DSL helper, the following things are
      # handled out of the box :
      #
      #   - Exception tracking
      #   - DB connections (checkout, and checkin)
      #   - A new logger is created, and start and finish of the call are logged
      #   - The call is benchmarked with Watchman
      #   - User_id and Org_id are extracted from call metadata
      #   - The success statsd metric is incremented
      #   - The failure statsd metric is incremented
      #
      # Usage:
      #
      #   Extend your service class with the GrpcDSL module and define the metric namespace.
      #   After this, use the define_rpc method to implement your RPC calls.
      #
      #   Example:
      #
      #   class Server < InternalApi::Auth::Authorization::Service
      #     extend InternalApi::GrpcDsl
      #
      #     rpc_metric_namespace "authentication_api"
      #
      #     define_rpc :authenticate do |request, logger, call|
      #       if request.username == "shiroyasha"
      #         InternalApi::Auth::AuthResponse.new(:authentication => true)
      #       else
      #         InternalApi::Auth::AuthResponse.new(:authentication => true)
      #       end
      #     end
      #
      #   end
      #

      module_function

      def define_rpc(method_name, &block)
        namespace = @rpc_metric_namespace

        raise "rpc metric namespace not set for InternalApi::GrpcDsl" unless namespace

        define_method(method_name) do |request, call|
          Semaphore::Grpc::Dsl.with_managed_db_connection do
            Semaphore::Grpc::Dsl.with_logs(namespace, method_name) do |logger|
              Semaphore::Grpc::Dsl.with_recorded_exceptions(request) do
                Semaphore::Grpc::Dsl.with_metrics(namespace, method_name) do
                  Semaphore::Grpc::Dsl.with_headers(call) do |headers|
                    instance_exec(request, headers, logger, call, &block)
                  end
                end
              end
            end
          end
        end
      end

      def rpc_metric_namespace(name)
        @rpc_metric_namespace = name
      end

      def with_managed_db_connection
        yield
      ensure
        ::ActiveRecord::Base.connection_handler.clear_active_connections!
      end

      def with_logs(service_name, method_name)
        Logman.process("#{service_name}-#{method_name}") do |logger|
          yield(logger)
        end
      end

      def with_metrics(service_name, method_name)
        label = "#{service_name}.#{method_name}.duration"
        Watchman.benchmark(label) do
          response = yield
          Watchman.increment("#{label}.success")
          response
        rescue StandardError => ex
          Watchman.increment("#{label}.failure")
          raise ex
        end
      end

      def with_headers(call)
        headers = OpenStruct.new(
          :user_id => call.metadata.fetch("x-semaphore-user-id"),
          :org_id => call.metadata.fetch("x-semaphore-org-id")
        )
        Exceptions.set_user_context({ :id => headers.user_id })

        yield(headers)
      end

      def with_recorded_exceptions(request)
        Exceptions.set_custom_context('request', request.to_h)

        yield
      rescue GRPC::BadStatus => ex
        raise ex
      rescue StandardError => ex
        Exceptions.notify(ex, {})
        raise ex
      end
    end
  end
end
