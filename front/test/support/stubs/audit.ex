defmodule Support.Stubs.AuditLog do
  alias GRPC.RPCError
  alias InternalApi.Audit.Event.{Medium, Operation, Resource}
  alias Support.Stubs.{DB, UUID}

  require Logger

  def init do
    DB.add_table(:audit_events, [
      :resource,
      :operation,
      :timestamp,
      :org_id,
      :user_id,
      :username,
      :ip_address,
      :resource_id,
      :resource_name,
      :metadata,
      :medium,
      :description,
      :operation_id
    ])

    DB.add_table(:stream_settings, [
      :id,
      :org_id,
      :provider,
      :status,
      :last_streamed,
      :metadata,
      :created_at,
      :updated_at,
      :activity_toggled_at,
      :updated_by,
      :activity_toggled_by
    ])

    DB.add_table(:stream_logs, [
      :id,
      :timestamp,
      :error_message,
      :file_size,
      :file_name,
      :first_event_timestamp,
      :last_event_timestamp
    ])

    DB.insert(:stream_settings, %{
      id: UUID.gen(),
      org_id: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21",
      provider: InternalApi.Audit.StreamProvider.value(:S3),
      status: InternalApi.Audit.StreamStatus.value(:ACTIVE),
      last_streamed: Timex.now(),
      metadata:
        InternalApi.Audit.S3StreamConfig.new(
          bucket: "my-bucket",
          key_id: "asfa-sf-asdf-as-dfa-dfa",
          key_secret: "sdfasfasdfasdfa-d-fa-sdfa-sfda"
        ),
      created_at: Timex.shift(Timex.now(), days: -1),
      updated_at: Timex.shift(Timex.now(), hours: -2),
      activity_toggled_at: Timex.shift(Timex.now(), minutes: -20),
      updated_by: "78114608-be8a-465a-b9cd-81970fb802c5",
      activity_toggled_by: "78114608-be8a-465a-b9cd-81970fb802c5"
    })

    DB.insert(:stream_settings, %{
      id: UUID.gen(),
      org_id: "92be62c2-9cf4-4dad-b168-d6efa6aa5e22",
      provider: InternalApi.Audit.StreamProvider.value(:S3),
      status: InternalApi.Audit.StreamStatus.value(:ACTIVE),
      last_streamed: Timex.now(),
      metadata:
        InternalApi.Audit.S3StreamConfig.new(
          bucket: "my-bucket",
          region: "us-east-1",
          type: InternalApi.Audit.S3StreamConfig.Type.value(:INSTANCE_ROLE)
        ),
      created_at: Timex.shift(Timex.now(), days: -1),
      updated_at: Timex.shift(Timex.now(), hours: -2),
      activity_toggled_at: Timex.shift(Timex.now(), minutes: -20),
      updated_by: "78114608-be8a-465a-b9cd-81970fb802c5",
      activity_toggled_by: "78114608-be8a-465a-b9cd-81970fb802c5"
    })

    DB.insert(:audit_events, %{
      org_id: UUID.gen(),
      resource: Resource.value(:Secret),
      operation: Operation.value(:Added),
      user_id: UUID.gen(),
      username: "shiroyasha",
      ip_address: "189.0.12.2",
      operation_id: UUID.gen(),
      timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
      resource_id: UUID.gen(),
      resource_name: "my-secret",
      metadata: Poison.encode!(%{"hello" => "world"}),
      medium: Medium.value(:API),
      description: "Removed my-secret to the organization"
    })

    DB.insert(:audit_events, %{
      org_id: UUID.gen(),
      resource: Resource.value(:Secret),
      operation: Operation.value(:Removed),
      user_id: UUID.gen(),
      username: "shiroyasha",
      ip_address: "189.0.12.2",
      operation_id: UUID.gen(),
      timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_000),
      resource_id: UUID.gen(),
      resource_name: "my-secret",
      metadata: Poison.encode!(%{"hello" => "world"}),
      medium: Medium.value(:Web),
      description: "Removed my-secret from the orgnaization"
    })

    DB.insert(:stream_logs, %{
      id: UUID.gen(),
      timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_000),
      error_message: "",
      file_size: 12_649,
      file_name: "AuditLog-2022-06-30T13:28:11-2022-07-04T15:35:57.csv",
      first_event_timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_000),
      last_event_timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_954_000)
    })

    DB.insert(:stream_logs, %{
      id: UUID.gen(),
      timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_955_000),
      error_message: "s3 was not accessible",
      file_size: 100_000,
      file_name: "AuditLog-2022-06-30T13:28:11-2022-07-04T15:35:57.csv",
      first_event_timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_954_000),
      last_event_timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_954_000)
    })

    __MODULE__.Grpc.init()
  end

  def add_event(resource, operation, event) do
    event_base = %{
      org_id: UUID.gen(),
      user_id: UUID.gen(),
      resource: Resource.value(resource),
      operation: Operation.value(operation),
      operation_id: UUID.gen(),
      username: "shiroyasha",
      ip_address: "189.0.12.2",
      resource_id: UUID.gen(),
      timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_000),
      medium: Medium.value(:Web)
    }

    event = Map.merge(event_base, event)

    DB.insert(:audit_events, event)
  end

  defmodule Grpc do
    alias InternalApi.Audit, as: API

    def init do
      GrpcMock.stub(AuditMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(AuditMock, :paginated_list, &__MODULE__.paginated_list/2)

      GrpcMock.stub(AuditMock, :test_stream, &__MODULE__.test_stream/2)
      GrpcMock.stub(AuditMock, :destroy_stream, &__MODULE__.destroy_stream/2)
      GrpcMock.stub(AuditMock, :create_stream, &__MODULE__.create_stream/2)
      GrpcMock.stub(AuditMock, :update_stream, &__MODULE__.update_stream/2)
      GrpcMock.stub(AuditMock, :describe_stream, &__MODULE__.describe_stream/2)
      GrpcMock.stub(AuditMock, :list_stream_logs, &__MODULE__.list_stream_logs/2)
      GrpcMock.stub(AuditMock, :set_stream_state, &__MODULE__.set_stream_state/2)
    end

    def list(request = %API.ListRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> list()

    def paginated_list(request = %API.PaginatedListRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> paginated_list()

    def test_stream(request = %API.TestStreamRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> test_stream()

    def create_stream(request = %API.CreateStreamRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> create_stream()

    def update_stream(request = %API.UpdateStreamRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> update_stream()

    def describe_stream(request = %API.DescribeStreamRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> describe_stream()

    def destroy_stream(request = %API.DestroyStreamRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> destroy_stream()

    def list_stream_logs(request = %API.ListStreamLogsRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> list_stream_logs()

    def set_stream_state(request = %API.SetStreamStateRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> set_stream_state()

    defp list(%{org_id: _org_id}) do
      events =
        DB.all(:audit_events)
        |> error("events")
        |> Enum.map(&serialize_event/1)

      API.ListResponse.new(events: events)
    end

    defp error(item, tag) do
      require Logger
      Logger.error("#{tag}: #{inspect(item)}")
      item
    end

    defp paginated_list(%{org_id: _org_id, page_size: _page_size, page_token: _page_token}) do
      events = DB.all(:audit_events) |> Enum.map(&serialize_event/1)

      API.PaginatedListResponse.new(
        events: events,
        next_page_token: "test",
        previous_page_token: ""
      )
    end

    defp create_stream(%{
           stream: %{org_id: org_id, provider: provider, status: _status, s3_config: s3_config}
         }) do
      if stream = DB.find_by(:stream_settings, :org_id, org_id),
        do: DB.delete(:stream_settings, stream.id)

      metadata =
        API.S3StreamConfig.new(
          s3_config
          |> Map.replace(:type, API.S3StreamConfig.Type.value(s3_config.type))
        )

      DB.insert(:stream_settings, %{
        id: UUID.gen(),
        org_id: org_id,
        provider: API.StreamProvider.value(provider),
        status: API.StreamStatus.value(:ACTIVE),
        last_streamed: nil,
        metadata: metadata,
        created_at: Timex.shift(Timex.now(), days: -1),
        updated_at: Timex.shift(Timex.now(), hours: -2),
        updated_by: "78114608-be8a-465a-b9cd-81970fb802c5",
        activity_toggled_at: Timex.shift(Timex.now(), hours: -2),
        activity_toggled_by: "78114608-be8a-465a-b9cd-81970fb802c5"
      })

      Util.Proto.deep_new!(
        %{
          stream: %{
            org_id: org_id,
            provider: API.StreamProvider.value(provider),
            status: API.StreamStatus.value(:ACTIVE),
            s3_config: s3_config
          }
        },
        API.CreateStreamResponse
      )
    end

    defp update_stream(%{
           stream: %{org_id: org_id, provider: provider, status: _status, s3_config: s3_config}
         }) do
      if stream = DB.find_by(:stream_settings, :org_id, org_id),
        do: DB.delete(:stream_settings, stream.id)

      DB.insert(:stream_settings, %{
        id: UUID.gen(),
        org_id: org_id,
        provider: API.StreamProvider.value(provider),
        status: API.StreamStatus.value(:ACTIVE),
        last_streamed: nil,
        metadata: API.S3StreamConfig.new(s3_config),
        created_at: Timex.shift(Timex.now(), days: -1),
        updated_at: Timex.shift(Timex.now(), hours: -2),
        updated_by: "78114608-be8a-465a-b9cd-81970fb802c5",
        activity_toggled_at: Timex.shift(Timex.now(), hours: -2),
        activity_toggled_by: "78114608-be8a-465a-b9cd-81970fb802c5"
      })

      Util.Proto.deep_new!(
        %{
          stream: %{
            org_id: org_id,
            provider: API.StreamProvider.value(provider),
            status: API.StreamStatus.value(:ACTIVE),
            s3_config: s3_config
          }
        },
        API.UpdateStreamResponse
      )
    end

    defp describe_stream(%{
           org_id: org_id
         }) do
      stream = DB.find_by(:stream_settings, :org_id, org_id)

      case stream do
        nil ->
          # raise RPCError.exception(
          #         Status.not_found(),
          #         "Stream not found"
          #       )
          raise RPCError, status: 5, message: "Stream not found"

        stream = %{metadata: %API.S3StreamConfig{}} ->
          API.DescribeStreamResponse.new(
            stream:
              API.Stream.new(
                org_id: stream.org_id,
                provider: stream.provider,
                status: stream.status,
                s3_config: stream.metadata
              ),
            meta:
              API.EditMeta.new(
                created_at:
                  Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(stream.created_at)),
                updated_at:
                  Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(stream.updated_at)),
                activity_toggled_at:
                  Google.Protobuf.Timestamp.new(
                    seconds: Timex.to_unix(stream.activity_toggled_at)
                  ),
                updated_by: stream.updated_by,
                activity_toggled_by: stream.activity_toggled_by
              )
          )
      end
    end

    defp destroy_stream(%{
           org_id: org_id
         }) do
      if stream = DB.find_by(:stream_settings, :org_id, org_id) do
        DB.delete(:stream_settings, stream.id)
        Google.Protobuf.Empty.new()
      else
        raise RPCError, status: 5, message: "Stream not found"
      end
    end

    defp list_stream_logs(%{
           org_id: org_id,
           page_size: _page_size,
           page_token: _page_token,
           direction: _direction
         }) do
      if _stream = DB.find_by(:stream_settings, :org_id, org_id) do
        logs = DB.all(:stream_logs) |> Enum.map(&serialize_stream_log/1)

        API.ListStreamLogsResponse.new(
          stream_logs: logs,
          next_page_token: "test",
          previous_page_token: ""
        )
      else
        API.ListStreamLogsResponse.new()
      end
    end

    defp test_stream(%{
           stream: %{
             provider: :S3,
             s3_config: %{
               bucket: _bucket,
               secret_name: _secret_name
             }
           }
         }) do
      Util.Proto.deep_new!(
        %{
          success: true,
          message: "Successfully connected to S3"
        },
        API.TestStreamResponse
      )
    end

    defp test_stream(%{}) do
      Util.Proto.deep_new!(
        %{
          success: false,
          message: "Error connecting to S3: some error"
        },
        API.TestStreamResponse
      )
    end

    defp set_stream_state(%{org_id: org_id, user_id: user_id})
         when org_id == "" or user_id == "" do
      if org_id == "" do
        raise RPCError,
          status: GRPC.Status.invalid_argument(),
          message: "Organization id is required"
      else
        raise RPCError, status: GRPC.Status.invalid_argument(), message: "User id is required"
      end
    end

    defp set_stream_state(%{org_id: org_id, user_id: _user_id, status: status}) do
      stream = DB.find_by(:stream_settings, :org_id, org_id)

      case stream do
        nil ->
          raise RPCError, status: 2, message: "Failed to set stream state: stream not found"

        stream ->
          stream = Map.replace(stream, :status, API.StreamStatus.value(status))
          DB.update(:stream_settings, stream)

          Google.Protobuf.Empty.new()
      end
    end

    defp serialize_stream_log(l) do
      API.StreamLog.new(
        timestamp: l.timestamp,
        error_message: l.error_message,
        file_size: l.file_size,
        file_name: l.file_name,
        first_event_timestamp: l.first_event_timestamp,
        last_event_timestamp: l.last_event_timestamp
      )
    end

    def serialize_event(e) do
      API.Event.new(
        resource: e.resource,
        operation: e.operation,
        timestamp: e.timestamp,
        org_id: e.org_id,
        user_id: e.user_id,
        operation_id: e.operation_id,
        ip_address: e.ip_address,
        username: e.username,
        resource_id: e.resource_id,
        resource_name: e.resource_name,
        metadata: e.metadata,
        medium: e.medium,
        description: e.description
      )
    end
  end
end
