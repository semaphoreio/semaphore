defmodule Audit.ApiTest do
  use Support.DataCase

  alias InternalApi.Audit.Event.{Resource, Operation, Medium}
  alias InternalApi.Audit.Stream

  test "listing events" do
    org_id = Ecto.UUID.generate()

    create_events(org_id)

    request = InternalApi.Audit.ListRequest.new(org_id: org_id)
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, res} = InternalApi.Audit.AuditService.Stub.list(channel, request)

    assert length(res.events) == 5
    assert Enum.at(res.events, 0).resource == :Secret
    assert Enum.at(res.events, 0).operation == :Added
    assert Enum.at(res.events, 0).org_id == org_id
    assert Enum.at(res.events, 0).username == "hello"
    assert Enum.at(res.events, 0).ip_address == "1.1.1.1"
    assert Enum.at(res.events, 0).resource_id != ""
    assert Enum.at(res.events, 0).resource_name == "my-secret"

    assert Enum.at(res.events, 0).metadata ==
             Poison.encode!(%{
               "hello" => "world"
             })

    assert Enum.at(res.events, 0).medium == :Web

    assert Enum.at(res.events, 1).resource == :Secret
    assert Enum.at(res.events, 1).operation == :Added
    assert Enum.at(res.events, 1).org_id == org_id
    assert Enum.at(res.events, 1).username == "hello"
    assert Enum.at(res.events, 1).ip_address == "1.1.1.1"
    assert Enum.at(res.events, 1).resource_id != ""
    assert Enum.at(res.events, 1).resource_name == "my-secret"

    assert Enum.at(res.events, 1).metadata ==
             Poison.encode!(%{
               "hello" => "world",
               "how" => "are you?"
             })

    assert Enum.at(res.events, 0).medium == :Web

    assert Enum.at(res.events, 2).resource == :Secret
    assert Enum.at(res.events, 2).operation == :Removed
    assert Enum.at(res.events, 2).org_id == org_id
    assert Enum.at(res.events, 2).username == "hello"
    assert Enum.at(res.events, 2).ip_address == "1.2.1.1"
    assert Enum.at(res.events, 2).resource_name == "my-secret"
    assert Enum.at(res.events, 2).resource_id != ""

    assert Enum.at(res.events, 2).metadata ==
             Poison.encode!(%{"hello" => "world"})

    assert Enum.at(res.events, 2).medium == :Web
  end

  test "listing event with pagination" do
    org_id = Ecto.UUID.generate()

    %{op1: _op1, op2: op2, op3: op3} = create_events(org_id)

    request = InternalApi.Audit.PaginatedListRequest.new(org_id: org_id, page_size: 1)
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, res} = InternalApi.Audit.AuditService.Stub.paginated_list(channel, request)

    assert length(res.events) == 1
    assert Enum.at(res.events, 0).resource == :Secret
    assert Enum.at(res.events, 0).operation == :Removed
    assert Enum.at(res.events, 0).org_id == org_id
    assert Enum.at(res.events, 0).username == "hello"
    assert Enum.at(res.events, 0).ip_address == "1.3.1.1"
    assert Enum.at(res.events, 0).resource_id != ""
    assert Enum.at(res.events, 0).resource_name == "my-secret"

    assert Enum.at(res.events, 0).metadata ==
             Poison.encode!(%{"who" => "are you?"})

    assert Enum.at(res.events, 0).operation_id == op3

    assert Enum.at(res.events, 0).medium == :Web

    assert res.previous_page_token == ""

    assert res.next_page_token ==
             %Audit.Event{
               operation_id: op3,
               timestamp: DateTime.from_unix!(45)
             }
             |> Paginator.cursor_for_record([:operation_id, :timestamp])

    # 2nd page, for previous page token to work, we need at least page_size: 2
    request =
      InternalApi.Audit.PaginatedListRequest.new(
        org_id: org_id,
        page_size: 2,
        page_token: res.next_page_token
      )

    {:ok, res} = InternalApi.Audit.AuditService.Stub.paginated_list(channel, request)

    # assert values
    assert length(res.events) == 2
    assert Enum.at(res.events, 0).resource == :Secret
    assert Enum.at(res.events, 0).operation == :Removed
    assert Enum.at(res.events, 0).org_id == org_id
    assert Enum.at(res.events, 0).username == "hello"
    assert Enum.at(res.events, 0).ip_address == "1.2.1.1"
    assert Enum.at(res.events, 0).resource_id != ""
    assert Enum.at(res.events, 0).resource_name == "my-secret"
    assert Enum.at(res.events, 0).operation_id == op2

    assert Enum.at(res.events, 0).metadata ==
             Poison.encode!(%{"hello" => "world", "how" => "are you doing?"})

    assert Enum.at(res.events, 0).medium == :Web

    assert res.next_page_token ==
             %Audit.Event{
               operation_id: op2,
               timestamp: DateTime.from_unix!(30)
             }
             |> Paginator.cursor_for_record([:operation_id, :timestamp])

    assert res.previous_page_token ==
             %Audit.Event{
               operation_id: op2,
               timestamp: DateTime.from_unix!(40)
             }
             |> Paginator.cursor_for_record([:operation_id, :timestamp])
  end

  test ".serialize_event" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    {:ok, event} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Added),
        org_id: org_id,
        user_id: user_id,
        username: "hello",
        ip_address: "1.2.3.4",
        operation_id: Ecto.UUID.generate(),
        timestamp: DateTime.from_unix!(0),
        resource_id: Ecto.UUID.generate(),
        resource_name: "my-secret",
        metadata: %{"hello" => "world"},
        medium: Medium.value(:CLI)
      })

    serialized = Audit.Api.serialize_event(event)

    assert serialized.resource == Resource.value(:Secret)
    assert serialized.operation == Operation.value(:Added)
    assert serialized.org_id == org_id
    assert serialized.user_id == user_id
    assert serialized.ip_address == "1.2.3.4"
    assert serialized.operation_id == event.operation_id
    assert serialized.username == "hello"
    assert serialized.resource_id == event.resource_id
    assert serialized.resource_name == event.resource_name
    assert serialized.metadata == Poison.encode!(event.metadata)
    assert serialized.medium == Medium.value(:CLI)
  end

  test "create export stream without user_id" do
    org_id = Ecto.UUID.generate()

    request =
      InternalApi.Audit.CreateStreamRequest.new(
        stream:
          Stream.new(
            org_id: org_id,
            provider: InternalApi.Audit.StreamProvider.value(:S3),
            s3_config:
              InternalApi.Audit.S3StreamConfig.new(
                bucket: "my-bucket",
                key_id: "key-id",
                key_secret: "the-cake-is-a-lie-secret"
              )
          )
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:error, res} = InternalApi.Audit.AuditService.Stub.create_stream(channel, request)

    assert res.message == "user_id required"
    assert res.status == GRPC.Status.invalid_argument()
  end

  test "create export stream with invalid host" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    request =
      InternalApi.Audit.CreateStreamRequest.new(
        user_id: user_id,
        stream:
          Stream.new(
            org_id: org_id,
            provider: InternalApi.Audit.StreamProvider.value(:S3),
            s3_config:
              InternalApi.Audit.S3StreamConfig.new(
                bucket: "my-bucket",
                key_id: "key-id",
                key_secret: "the-cake-is-a-lie-secret",
                host: "127.0.0.1"
              )
          )
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:error, res} = InternalApi.Audit.AuditService.Stub.create_stream(channel, request)

    assert res.message == "Failed to save stream: invalid host"
    assert res.status == GRPC.Status.unknown()
  end

  test "create export stream" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    request =
      InternalApi.Audit.CreateStreamRequest.new(
        user_id: user_id,
        stream:
          Stream.new(
            org_id: org_id,
            provider: InternalApi.Audit.StreamProvider.value(:S3),
            s3_config:
              InternalApi.Audit.S3StreamConfig.new(
                bucket: "my-bucket",
                key_id: "key-id",
                key_secret: "the-cake-is-a-lie-secret"
              )
          )
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, res} = InternalApi.Audit.AuditService.Stub.create_stream(channel, request)

    assert res.stream.provider == :S3

    assert res.stream.s3_config.bucket == "my-bucket"
    assert res.stream.s3_config.key_id == "key-id"
    assert res.stream.s3_config.key_secret == "the-cake-is-a-lie-secret"
    assert res.stream.s3_config.type == :USER

    assert res.meta.updated_by == user_id

    {:ok, config} =
      Audit.Streamer.Config.get_one(%{
        org_id: org_id,
        provider: InternalApi.Audit.StreamProvider.value(:S3)
      })

    assert config.provider == :S3

    assert config.metadata == %{
             bucket_name: "my-bucket",
             host: "",
             region: ""
           }

    assert config.cridentials == %{
             key_id: "key-id",
             key_secret: "the-cake-is-a-lie-secret",
             type: "USER"
           }

    assert config.updated_by == user_id
    assert config.activity_toggled_by == user_id
  end

  test "create export stream using instance role" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    request =
      InternalApi.Audit.CreateStreamRequest.new(
        user_id: user_id,
        stream:
          Stream.new(
            org_id: org_id,
            provider: InternalApi.Audit.StreamProvider.value(:S3),
            s3_config:
              InternalApi.Audit.S3StreamConfig.new(
                bucket: "my-bucket",
                type: :INSTANCE_ROLE
              )
          )
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, res} = InternalApi.Audit.AuditService.Stub.create_stream(channel, request)

    assert res.stream.provider == :S3

    assert res.stream.s3_config.bucket == "my-bucket"
    assert res.stream.s3_config.type == :INSTANCE_ROLE

    assert res.meta.updated_by == user_id

    {:ok, config} =
      Audit.Streamer.Config.get_one(%{
        org_id: org_id,
        provider: InternalApi.Audit.StreamProvider.value(:S3)
      })

    assert config.provider == :S3

    assert config.metadata == %{
             bucket_name: "my-bucket",
             region: ""
           }

    assert config.cridentials == %{
             type: "INSTANCE_ROLE"
           }

    assert config.updated_by == user_id
    assert config.activity_toggled_by == user_id
  end

  test "create existing stream" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    {:ok, stream} = create_stream(org_id, user_id)

    request =
      InternalApi.Audit.CreateStreamRequest.new(
        user_id: user_id,
        stream:
          Stream.new(
            org_id: org_id,
            provider: InternalApi.Audit.StreamProvider.value(:S3),
            s3_config:
              InternalApi.Audit.S3StreamConfig.new(
                bucket: "my-bucket-update",
                key_id: "key-id",
                key_secret: "the-cake-is-a-lie-secret"
              )
          )
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:error, res} = InternalApi.Audit.AuditService.Stub.create_stream(channel, request)

    assert res.message == "stream already exists, delete it to create new one"
    assert res.status == GRPC.Status.already_exists()

    {:ok, config} =
      Audit.Streamer.Config.get_one(%{
        org_id: org_id,
        provider: InternalApi.Audit.StreamProvider.value(:S3)
      })

    assert config.provider == :S3

    assert config.metadata == stream.metadata
    assert config.cridentials == stream.cridentials
  end

  test "create existing stream using instance role" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    {:ok, stream} = create_instance_stream(org_id, user_id)

    request =
      InternalApi.Audit.CreateStreamRequest.new(
        user_id: user_id,
        stream:
          Stream.new(
            org_id: org_id,
            provider: InternalApi.Audit.StreamProvider.value(:S3),
            s3_config:
              InternalApi.Audit.S3StreamConfig.new(
                bucket: "my-bucket-update",
                type: :INSTANCE_ROLE
              )
          )
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:error, res} = InternalApi.Audit.AuditService.Stub.create_stream(channel, request)

    assert res.message == "stream already exists, delete it to create new one"
    assert res.status == GRPC.Status.already_exists()

    {:ok, config} =
      Audit.Streamer.Config.get_one(%{
        org_id: org_id,
        provider: InternalApi.Audit.StreamProvider.value(:S3)
      })

    assert config.provider == :S3

    assert config.metadata == stream.metadata
    assert config.cridentials == stream.cridentials
  end

  test "describe s3 stream" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    create_stream(org_id, user_id)

    request = InternalApi.Audit.DescribeStreamRequest.new(org_id: org_id)

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, res} = InternalApi.Audit.AuditService.Stub.describe_stream(channel, request)

    assert res.stream.provider == :S3

    assert res.stream.s3_config.bucket == "my-bucket"
    assert res.stream.s3_config.key_id == "key-id"
    assert res.stream.s3_config.key_secret == "the-cake-is-a-lie-secret"

    assert res.meta.updated_by == user_id
  end

  test "describe s3 stream using instance role" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    create_instance_stream(org_id, user_id)

    request = InternalApi.Audit.DescribeStreamRequest.new(org_id: org_id)

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, res} = InternalApi.Audit.AuditService.Stub.describe_stream(channel, request)

    assert res.stream.provider == :S3

    assert res.stream.s3_config.bucket == "my-bucket"
    assert res.stream.s3_config.type == :INSTANCE_ROLE

    assert res.meta.updated_by == user_id
  end

  test "update s3 stream" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    create_stream(org_id, user_id)

    request =
      InternalApi.Audit.UpdateStreamRequest.new(
        user_id: user_id,
        stream:
          Stream.new(
            org_id: org_id,
            provider: InternalApi.Audit.StreamProvider.value(:S3),
            s3_config:
              InternalApi.Audit.S3StreamConfig.new(
                bucket: "my-bucket-update",
                key_id: "key-id-update",
                key_secret: "the-cake-is-a-lie-secret-update"
              )
          )
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, res} = InternalApi.Audit.AuditService.Stub.update_stream(channel, request)

    assert res.stream.s3_config == request.stream.s3_config

    {:ok, config} = Audit.Streamer.Config.get_one(%{org_id: org_id})

    assert config.metadata == %{
             bucket_name: "my-bucket-update",
             host: "",
             region: ""
           }

    assert config.cridentials == %{
             key_id: "key-id-update",
             key_secret: "the-cake-is-a-lie-secret-update",
             type: "USER"
           }
  end

  test "update s3 stream using instance role" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    create_stream(org_id, user_id)

    request =
      InternalApi.Audit.UpdateStreamRequest.new(
        user_id: user_id,
        stream:
          Stream.new(
            org_id: org_id,
            provider: InternalApi.Audit.StreamProvider.value(:S3),
            s3_config:
              InternalApi.Audit.S3StreamConfig.new(
                bucket: "my-bucket-update",
                type: :INSTANCE_ROLE
              )
          )
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, res} = InternalApi.Audit.AuditService.Stub.update_stream(channel, request)

    assert res.stream.s3_config == request.stream.s3_config

    {:ok, config} = Audit.Streamer.Config.get_one(%{org_id: org_id})

    assert config.metadata == %{
             bucket_name: "my-bucket-update",
             region: ""
           }

    assert config.cridentials == %{
             type: "INSTANCE_ROLE"
           }
  end

  test "update s3 stream with invalid host" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    create_stream(org_id, user_id)

    request =
      InternalApi.Audit.UpdateStreamRequest.new(
        user_id: user_id,
        stream:
          Stream.new(
            org_id: org_id,
            provider: InternalApi.Audit.StreamProvider.value(:S3),
            s3_config:
              InternalApi.Audit.S3StreamConfig.new(
                bucket: "my-bucket",
                key_id: "key-id",
                key_secret: "the-cake-is-a-lie-secret",
                host: "127.0.0.1"
              )
          )
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:error, res} = InternalApi.Audit.AuditService.Stub.update_stream(channel, request)

    assert res.message == "Failed to save stream: invalid host"
    assert res.status == GRPC.Status.unknown()
  end

  test "pause => unpause stream" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    {:ok, original} = create_stream(org_id, user_id)
    other_user_id = Ecto.UUID.generate()

    request =
      InternalApi.Audit.SetStreamStateRequest.new(
        org_id: org_id,
        status: InternalApi.Audit.StreamStatus.value(:PAUSED),
        user_id: other_user_id
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, _} = InternalApi.Audit.AuditService.Stub.set_stream_state(channel, request)

    {:ok, config} = Audit.Streamer.Config.get_one(%{org_id: org_id, stream_id: original.id})

    assert config.status == :PAUSED
    assert Timex.to_unix(config.activity_toggled_at) > Timex.to_unix(original.activity_toggled_at)
    assert config.activity_toggled_by == other_user_id
    assert config.cridentials != nil
    assert config.cridentials.key_id == "key-id"
    assert config.cridentials.key_secret == "the-cake-is-a-lie-secret"

    assert config.metadata != nil
    assert config.metadata.bucket_name == "my-bucket"

    _time_paused = config.activity_toggled_at

    # :timer.sleep(:timer.seconds(1))

    ## unpause stream
    request =
      InternalApi.Audit.SetStreamStateRequest.new(
        org_id: org_id,
        status: InternalApi.Audit.StreamStatus.value(:ACTIVE),
        user_id: user_id
      )

    {:ok, _} = InternalApi.Audit.AuditService.Stub.set_stream_state(channel, request)

    {:ok, config} = Audit.Streamer.Config.get_one(%{org_id: org_id, stream_id: original.id})

    assert config.status == :ACTIVE
    # assert Timex.to_unix(config.activity_toggled_at) > Timex.to_unix(time_paused)
    assert config.activity_toggled_by == user_id
  end

  test "pause => unpause stream instance roles" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    {:ok, original} = create_instance_stream(org_id, user_id)
    other_user_id = Ecto.UUID.generate()

    request =
      InternalApi.Audit.SetStreamStateRequest.new(
        org_id: org_id,
        status: InternalApi.Audit.StreamStatus.value(:PAUSED),
        user_id: other_user_id
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, _} = InternalApi.Audit.AuditService.Stub.set_stream_state(channel, request)

    {:ok, config} = Audit.Streamer.Config.get_one(%{org_id: org_id, stream_id: original.id})

    assert config.status == :PAUSED
    assert Timex.to_unix(config.activity_toggled_at) > Timex.to_unix(original.activity_toggled_at)
    assert config.activity_toggled_by == other_user_id

    _time_paused = config.activity_toggled_at

    # :timer.sleep(:timer.seconds(1))

    ## unpause stream
    request =
      InternalApi.Audit.SetStreamStateRequest.new(
        org_id: org_id,
        status: InternalApi.Audit.StreamStatus.value(:ACTIVE),
        user_id: user_id
      )

    {:ok, _} = InternalApi.Audit.AuditService.Stub.set_stream_state(channel, request)

    {:ok, config} = Audit.Streamer.Config.get_one(%{org_id: org_id, stream_id: original.id})

    assert config.status == :ACTIVE
    # assert Timex.to_unix(config.activity_toggled_at) > Timex.to_unix(time_paused)
    assert config.activity_toggled_by == user_id
  end

  @tag disabled: true
  test "test stream" do
    org_id = Ecto.UUID.generate()

    req =
      InternalApi.Audit.TestStreamRequest.new(
        stream:
          InternalApi.Audit.Stream.new(
            org_id: org_id,
            provider: InternalApi.Audit.StreamProvider.value(:S3),
            status: InternalApi.Audit.StreamStatus.value(:ACTIVE),
            s3_config:
              InternalApi.Audit.S3StreamConfig.new(
                bucket: "test-bucket",
                key_id: "key-id",
                key_secret: "the-cake-is-a-lie-secret",
                host: "localhost"
              )
          )
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, resp} = InternalApi.Audit.AuditService.Stub.test_stream(channel, req)

    assert resp.success == true
  end

  test "list stream logs" do
    org_id = Ecto.UUID.generate()
    first_timestamp = DateTime.from_unix!(10)
    last_timestamp = DateTime.from_unix!(200)

    Audit.Streamer.Log.new(
      {:ok, 130},
      %{org_id: org_id, provider: :S3},
      first_timestamp,
      last_timestamp,
      Audit.Streamer.Scheduler.new_file_name(
        %{timestamp: first_timestamp},
        %{timestamp: last_timestamp}
      )
    )

    :timer.sleep(:timer.seconds(1))

    first_timestamp = DateTime.from_unix!(205)
    last_timestamp = DateTime.from_unix!(300)

    Audit.Streamer.Log.new(
      {:error, %{body: "some failed operation"}},
      %{org_id: org_id, provider: :S3},
      first_timestamp,
      last_timestamp,
      Audit.Streamer.Scheduler.new_file_name(
        %{timestamp: first_timestamp},
        %{timestamp: last_timestamp}
      )
    )

    request = InternalApi.Audit.ListStreamLogsRequest.new(org_id: org_id)

    {:ok, channel} = GRPC.Stub.connect("localhost:50051", deadline: :infinity)

    {:ok, res} =
      InternalApi.Audit.AuditService.Stub.list_stream_logs(channel, request, timeout: :infinity)

    assert length(res.stream_logs) == 2

    assert Enum.at(res.stream_logs, 0).error_message == "some failed operation"
    assert Enum.at(res.stream_logs, 1).error_message == ""
  end

  def create_stream(org_id, user_id) do
    Audit.Streamer.Config.create(%{
      org_id: org_id,
      provider: InternalApi.Audit.StreamProvider.value(:S3),
      paused: false,
      metadata: %{
        bucket_name: "my-bucket",
        host: ""
      },
      cridentials: %{
        key_id: "key-id",
        key_secret: "the-cake-is-a-lie-secret"
      },
      created_at: DateTime.from_unix!(100),
      updated_at: DateTime.from_unix!(100),
      updated_by: user_id,
      activity_toggled_at: DateTime.from_unix!(100),
      activity_toggled_by: user_id
    })
  end

  def create_instance_stream(org_id, user_id) do
    Audit.Streamer.Config.create(%{
      org_id: org_id,
      provider: InternalApi.Audit.StreamProvider.value(:S3),
      paused: false,
      metadata: %{
        bucket_name: "my-bucket"
      },
      cridentials: %{
        type: "INSTANCE_ROLE"
      },
      created_at: DateTime.from_unix!(100),
      updated_at: DateTime.from_unix!(100),
      updated_by: user_id,
      activity_toggled_at: DateTime.from_unix!(100),
      activity_toggled_by: user_id
    })
  end

  def create_events(org_id) do
    operation1 = Ecto.UUID.generate()
    operation2 = Ecto.UUID.generate()
    operation3 = Ecto.UUID.generate()

    user_id1 = Ecto.UUID.generate()
    user_id2 = Ecto.UUID.generate()

    {:ok, _} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Added),
        org_id: org_id,
        user_id: user_id1,
        username: "hello",
        operation_id: operation1,
        ip_address: "1.1.1.1",
        timestamp: DateTime.from_unix!(0),
        resource_id: Ecto.UUID.generate(),
        resource_name: "my-secret",
        metadata: %{"hello" => "world"},
        medium: Medium.value(:Web)
      })

    {:ok, _} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Added),
        org_id: org_id,
        user_id: user_id1,
        username: "hello",
        operation_id: operation1,
        ip_address: "1.1.1.1",
        timestamp: DateTime.from_unix!(20),
        resource_id: Ecto.UUID.generate(),
        resource_name: "my-secret",
        metadata: %{"hello" => "world", "how" => "are you?"},
        medium: Medium.value(:Web)
      })

    {:ok, _} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Removed),
        org_id: org_id,
        user_id: user_id2,
        username: "hello",
        operation_id: operation2,
        ip_address: "1.2.1.1",
        timestamp: DateTime.from_unix!(30),
        resource_id: Ecto.UUID.generate(),
        resource_name: "my-secret",
        metadata: %{"hello" => "world"},
        medium: Medium.value(:Web)
      })

    {:ok, _} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Removed),
        org_id: org_id,
        user_id: user_id2,
        username: "hello",
        operation_id: operation2,
        ip_address: "1.2.1.1",
        timestamp: DateTime.from_unix!(40),
        resource_id: Ecto.UUID.generate(),
        resource_name: "my-secret",
        metadata: %{"hello" => "world", "how" => "are you doing?"},
        medium: Medium.value(:Web)
      })

    {:ok, _} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Removed),
        org_id: org_id,
        user_id: Ecto.UUID.generate(),
        username: "hello",
        operation_id: operation3,
        ip_address: "1.3.1.1",
        timestamp: DateTime.from_unix!(45),
        resource_id: Ecto.UUID.generate(),
        resource_name: "my-secret",
        metadata: %{"who" => "are you?"},
        medium: Medium.value(:Web)
      })

    %{op1: operation1, op2: operation2, op3: operation3}
  end
end
