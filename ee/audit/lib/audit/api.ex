defmodule Audit.Api do
  use GRPC.Server, service: InternalApi.Audit.AuditService.Service
  use Sentry.Grpc, service: InternalApi.Audit.AuditService.Service
  require Logger

  alias InternalApi.Audit, as: IA
  alias GRPC.{RPCError, Status}

  @max_page_size 500

  def list(request, _stream), do: observe("list", fn -> list(request) end)

  defp list(%IA.ListRequest{org_id: ""}) do
    raise RPCError.exception(
            Status.invalid_argument(),
            "org_id is required"
          )
  end

  defp list(req) do
    events =
      Audit.Event.all(%{org_id: req.org_id})
      |> Enum.map(&serialize_event/1)

    IA.ListResponse.new(events: events)
  end

  def paginated_list(req, _call), do: observe("paginated_list", fn -> paginated_list(req) end)

  defp paginated_list(%IA.PaginatedListRequest{org_id: ""}) do
    raise RPCError.exception(
            Status.invalid_argument(),
            "org_id is required"
          )
  end

  defp paginated_list(req) do
    {:ok, page_size} = non_empty_value_or_default(req, :page_size, 500)

    {events, next_token, previous_token} =
      Audit.Event.paginated(
        %{org_id: req.org_id},
        %{
          page_size: min(page_size, @max_page_size),
          page_token: req.page_token,
          direction: req.direction
        }
      )

    events = events |> Enum.map(&serialize_event/1)

    IA.PaginatedListResponse.new(
      events: events,
      next_page_token: next_token,
      previous_page_token: previous_token
    )
  end

  defp valid_stream(stream = %{provider: :S3, s3_config: _s3_config})
       when is_atom(stream.provider) do
    with true <- stream.s3_config.bucket != "",
         true <- stream.s3_config.type == :INSTANCE_ROLE or stream.s3_config.key_id != "",
         true <- stream.s3_config.type == :INSTANCE_ROLE or stream.s3_config.key_secret != "" do
      :ok
    else
      false ->
        raise RPCError.exception(
                Status.invalid_argument(),
                "bucket name and secret name are required"
              )
    end
  end

  def test_stream(req, _call), do: observe("test_stream", fn -> test_stream(req) end)

  defp test_stream(req) do
    :ok = valid_stream(req.stream)

    now =
      Timex.now()
      |> Timex.format!("{ISOdate}T{h24}:{m}:{s}")

    file_name = "seamphore-test-upload-" <> now

    case Audit.Streamer.check_access(req.stream, file_name) do
      {:error, {_, %{body: body}}} ->
        Watchman.increment("audit.test_stream.error")
        Logger.error("Error connecting to S3: #{body}")

        IA.TestStreamResponse.new(
          success: false,
          message: body
        )

      {:error, unknown} ->
        Watchman.increment("audit.test_stream.error")
        Logger.error("Unknown error connecting to S3: #{inspect(unknown)}")

        IA.TestStreamRequest.new(
          success: false,
          message: inspect(unknown)
        )

      {:ok, _} ->
        Watchman.increment("audit.test_stream.success")
        # attempt cleanup
        case Audit.Streamer.cleanup(req.stream, file_name) do
          {:ok, _} ->
            IA.TestStreamResponse.new(
              success: true,
              message: "Successfully connected to S3"
            )

          {:error, _} ->
            IA.TestStreamResponse.new(
              success: true,
              message: "Successfully connected to S3, but failed to cleanup test file"
            )
        end
    end
  end

  def create_stream(req, _call), do: observe("create_stream", fn -> create_stream(req) end)

  defp create_stream(req) when is_nil(req.user_id) or req.user_id == "",
    do: raise(RPCError.exception(Status.invalid_argument(), "user_id required"))

  defp create_stream(req) when req.user_id != "" do
    case Audit.Streamer.Config.get_one(%{org_id: req.stream.org_id}) do
      {:ok, _result} ->
        raise RPCError.exception(
                Status.already_exists(),
                "stream already exists, delete it to create new one"
              )

      {:not_found, _} ->
        result =
          Audit.Streamer.Config.create(%{
            org_id: req.stream.org_id,
            provider: IA.StreamProvider.value(req.stream.provider),
            status: IA.StreamStatus.value(:ACTIVE),
            metadata: Audit.Streamer.Config.api_to_metadata(req.stream),
            cridentials: Audit.Streamer.Config.api_to_cridentials(req.stream),
            created_at: Timex.now(),
            updated_at: Timex.now(),
            activity_toggled_at: Timex.now(),
            updated_by: req.user_id,
            activity_toggled_by: req.user_id
          })

        case result do
          {:ok, inserted} ->
            inserted =
              Map.update!(inserted, :provider, fn value -> IA.StreamProvider.key(value) end)

            IA.CreateStreamResponse.new(
              meta: serialize_meta(inserted),
              stream: serialize_stream(inserted)
            )

          {:error, msg} ->
            Logger.error("Failed to create S3 stream: #{msg}")

            raise RPCError.exception(
                    Status.unknown(),
                    "Failed to save stream: #{msg}"
                  )
        end
    end
  end

  def describe_stream(req, _call), do: observe("describe_stream", fn -> describe_stream(req) end)

  defp describe_stream(req) do
    result = Audit.Streamer.Config.get_one!(%{org_id: req.org_id})

    case result do
      nil ->
        raise RPCError.exception(
                Status.not_found(),
                "No stream found for org_id: #{req.org_id}"
              )

      stream ->
        IA.DescribeStreamResponse.new(
          meta: serialize_meta(stream),
          stream: serialize_stream(stream)
        )
    end
  end

  def update_stream(req, _call), do: observe("update_stream", fn -> update_stream(req) end)

  defp update_stream(req) when is_nil(req.user_id) or req.user_id == "",
    do: raise(RPCError.exception(Status.invalid_argument(), "user_id required"))

  defp update_stream(req) do
    result =
      case req.stream.provider do
        :S3 ->
          Audit.Streamer.Config.update(
            %{
              org_id: req.stream.org_id,
              provider: IA.StreamProvider.value(req.stream.provider)
            },
            %{
              metadata: Audit.Streamer.Config.api_to_metadata(req.stream),
              cridentials: Audit.Streamer.Config.api_to_cridentials(req.stream),
              updated_by: req.user_id,
              updated_at: Timex.now()
            }
          )
      end

    case result do
      {:ok, inserted} ->
        inserted = Map.update!(inserted, :provider, fn value -> IA.StreamProvider.key(value) end)

        IA.UpdateStreamResponse.new(
          meta: serialize_meta(inserted),
          stream: serialize_stream(inserted)
        )

      {:error, msg} ->
        Logger.error("Failed to update S3 stream: #{msg}")

        raise RPCError.exception(
                Status.unknown(),
                "Failed to save stream: #{msg}"
              )
    end
  end

  def set_stream_state(req, _call),
    do: observe("set_stream_state", fn -> set_stream_state(req) end)

  defp set_stream_state(req) when is_nil(req.user_id) or req.user_id == "",
    do: raise(RPCError.exception(Status.invalid_argument(), "user_id required"))

  defp set_stream_state(req) do
    result =
      Audit.Streamer.Config.update(%{org_id: req.org_id}, %{
        status: IA.StreamStatus.value(req.status),
        activity_toggled_at: Timex.now(),
        activity_toggled_by: req.user_id
      })

    case result do
      {:ok, _} ->
        Google.Protobuf.Empty.new()

      {:error, msg} ->
        Logger.error("Failed to pause stream #{req.org_id}: #{inspect(msg)}")

        raise RPCError.exception(
                Status.unknown(),
                "Failed to set stream state: #{inspect(msg)}"
              )
    end
  end

  def destroy_stream(req, _call), do: observe("destroy_stream", fn -> destroy_stream(req) end)

  defp destroy_stream(req) do
    observe("destroy_stream", fn ->
      result = Audit.Streamer.Config.delete(req.org_id)

      case result do
        {:ok, _} ->
          Google.Protobuf.Empty.new()

        {:error, msg} ->
          Logger.error("Failed to destroy stream #{req.stream_id}: #{inspect(msg)}")

          raise RPCError.exception(
                  Status.unknown(),
                  "Failed to destroy stream: #{inspect(msg)}"
                )
      end
    end)
  end

  def list_stream_logs(req, _call),
    do: observe("list_stream_logs", fn -> list_stream_logs(req) end)

  defp list_stream_logs(req) do
    case non_empty_value_or_default(req, :page_size, 20) do
      {:ok, page_size} ->
        {logs, next_token, previous_token} =
          Audit.Streamer.Log.list(req.org_id, %{
            page_size: min(page_size, @max_page_size),
            page_token: req.page_token,
            direction: req.direction
          })

        logs = logs |> Enum.map(&serialize_stream_log/1)

        IA.ListStreamLogsResponse.new(
          stream_logs: logs,
          next_token: next_token,
          previous_token: previous_token
        )

      _error ->
        raise RPCError.exception(
                Status.unknown(),
                ""
              )
    end
  end

  defp non_empty_value_or_default(map, key, default) do
    case Map.get(map, key) do
      val when is_integer(val) and val > 0 -> {:ok, val}
      val when is_binary(val) and val != "" -> {:ok, val}
      val when is_list(val) and length(val) > 0 -> {:ok, val}
      _ -> {:ok, default}
    end
  end

  def serialize_event(e) do
    IA.Event.new(
      resource: IA.Event.Resource.value(e.resource),
      operation: IA.Event.Operation.value(e.operation),
      timestamp: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(e.timestamp)),
      org_id: e.org_id,
      user_id: e.user_id,
      operation_id: e.operation_id,
      ip_address: e.ip_address,
      username: e.username,
      resource_id: e.resource_id,
      resource_name: e.resource_name,
      metadata: Poison.encode!(e.metadata),
      description: e.description,
      medium: IA.Event.Medium.value(e.medium)
    )
  end

  defp serialize_meta(s) do
    IA.EditMeta.new(
      created_at: timestamp(s.created_at),
      updated_at: timestamp(s.updated_at),
      activity_toggled_at: timestamp(s.activity_toggled_at),
      updated_by: s.updated_by,
      activity_toggled_by: s.activity_toggled_by
    )
  end

  defp timestamp(nil) do
    Google.Protobuf.Timestamp.new()
  end

  defp timestamp(t) do
    Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(t))
  end

  defp serialize_stream(s) do
    case s.provider do
      :S3 ->
        IA.Stream.new(
          org_id: s.org_id,
          provider: IA.StreamProvider.value(s.provider),
          s3_config: Audit.Streamer.Config.metadata_to_api(s),
          status: IA.StreamStatus.value(s.status)
        )
    end
  end

  defp serialize_stream_log(l) do
    IA.StreamLog.new(
      timestamp: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(l.streamed_at)),
      error_message: l.errors,
      first_event_timestamp:
        Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(l.first_event_timestamp)),
      last_event_timestamp:
        Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(l.last_event_timestamp)),
      file_name: l.file_name,
      file_size: l.file_size
    )
  end

  defp observe(action_name, f) do
    Watchman.benchmark("internal_audit_api.#{action_name}.duration", fn ->
      try do
        result = f.()

        Watchman.increment("internal_audit_api.#{action_name}.success")

        result
      rescue
        e ->
          Watchman.increment("internal_audit_api.#{action_name}.failure")
          Kernel.reraise(e, __STACKTRACE__)
      end
    end)
  end
end
