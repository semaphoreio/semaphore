defmodule HooksProcessor.RabbitMQConsumerTest do
  use ExUnit.Case

  alias HooksProcessor.Hooks.Processing.WorkersSupervisor
  alias HooksProcessor.Hooks.Model.HooksQueries
  alias InternalApi.Hooks.ReceivedWebhook
  alias HooksProcessor.RabbitMQConsumer

  @grpc_port 50_055

  setup_all do
    mocks = [RepositoryServiceMock]
    GRPC.Server.start(mocks, @grpc_port)

    Application.put_env(:hooks_processor, :repository_grpc_url, "localhost:#{inspect(@grpc_port)}")

    on_exit(fn ->
      GRPC.Server.stop(mocks)

      Test.Helpers.wait_until_stopped(mocks)
    end)

    {:ok, %{}}
  end

  setup do
    Test.Helpers.truncate_db()

    start_supervised!(WorkersSupervisor)

    :ok
  end

  test "message is properly decoded" do
    received_at = DateTime.utc_now()

    message =
      %ReceivedWebhook{
        received_at: date_time_to_timestamps(received_at),
        webhook: JSON.encode!(%{hello: "world"}),
        repository_id: "repo_1",
        project_id: "project_1",
        organization_id: "org_1",
        webhook_signature: "sha256=2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae",
        webhook_raw_payload: JSON.encode!(%{hello: "world"})
      }
      |> ReceivedWebhook.encode()

    assert {:ok, decoded} = RabbitMQConsumer.decode_message(message)
    assert decoded.webhook == %{"hello" => "world"}
    assert DateTime.compare(decoded.received_at, DateTime.utc_now()) == :lt
    assert decoded.repository_id == "repo_1"
    assert decoded.project_id == "project_1"
    assert decoded.organization_id == "org_1"
    assert decoded.webhook_signature == "sha256=2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae"
    assert decoded.webhook_raw_payload == "{\"hello\":\"world\"}"
  end

  test "valid message is pulled from the queue, the hook is verified and stored" do
    {:ok, ctx} = purge_queue("test")

    assert 0 = AMQP.Queue.message_count(ctx.channel, ctx.queue)

    options = %{
      exchange: "received_webhooks_exchange",
      routing_key: "test",
      url: Application.get_env(:hooks_processor, :amqp_url)
    }

    received_at = DateTime.utc_now()

    params = %ReceivedWebhook{
      received_at: date_time_to_timestamps(received_at),
      webhook: JSON.encode!(%{hello: "world"}),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      webhook_signature: "sha256=2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae",
      webhook_raw_payload: "{\"hello\":\"world\"}"
    }

    RepositoryServiceMock
    |> GrpcMock.expect(:verify_webhook_signature, fn req, _ ->
      assert req.organization_id == params.organization_id
      assert req.repository_id == params.repository_id
      assert req.payload == params.webhook_raw_payload
      assert req.signature == params.webhook_signature

      %InternalApi.Repository.VerifyWebhookSignatureResponse{valid: true}
    end)

    params
    |> ReceivedWebhook.encode()
    |> Tackle.publish(options)

    :timer.sleep(500)

    assert 0 = AMQP.Queue.message_count(ctx.channel, ctx.queue)
    AMQP.Connection.close(ctx.connection)

    assert {:ok, hook} = HooksQueries.get_by_repo_received_at(params.repository_id, received_at)

    assert hook.project_id == params.project_id
    assert hook.received_at == received_at
    assert hook.repository_id == params.repository_id
    assert hook.organization_id == params.organization_id
    assert hook.provider == "test"
    assert hook.request == %{"hello" => "world"}

    GrpcMock.verify!(RepositoryServiceMock)
  end

  test "valid message is pulled from the queue, when the hook has invalid signature, it's not processed" do
    {:ok, ctx} = purge_queue("test")

    assert 0 = AMQP.Queue.message_count(ctx.channel, ctx.queue)

    options = %{
      exchange: "received_webhooks_exchange",
      routing_key: "test",
      url: Application.get_env(:hooks_processor, :amqp_url)
    }

    received_at = DateTime.utc_now()

    params = %ReceivedWebhook{
      received_at: date_time_to_timestamps(received_at),
      webhook: JSON.encode!(%{hello: "world"}),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      webhook_signature: "sha256=2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae",
      webhook_raw_payload: "{\"hello\":\"world\"}"
    }

    RepositoryServiceMock
    |> GrpcMock.expect(:verify_webhook_signature, fn req, _ ->
      assert req.organization_id == params.organization_id
      assert req.repository_id == params.repository_id
      assert req.payload == params.webhook_raw_payload
      assert req.signature == params.webhook_signature

      %InternalApi.Repository.VerifyWebhookSignatureResponse{valid: false}
    end)

    params
    |> ReceivedWebhook.encode()
    |> Tackle.publish(options)

    :timer.sleep(500)

    assert 0 = AMQP.Queue.message_count(ctx.channel, ctx.queue)
    AMQP.Connection.close(ctx.connection)

    assert {:error, _} = HooksQueries.get_by_repo_received_at(params.repository_id, received_at)

    GrpcMock.verify!(RepositoryServiceMock)
  end

  test "valid message is pulled from the queue, when the hook signature fails, it retries" do
    {:ok, ctx} = purge_queue("test")

    assert 0 = AMQP.Queue.message_count(ctx.channel, ctx.queue)

    options = %{
      exchange: "received_webhooks_exchange",
      routing_key: "test",
      url: Application.get_env(:hooks_processor, :amqp_url)
    }

    received_at = DateTime.utc_now()

    params = %ReceivedWebhook{
      received_at: date_time_to_timestamps(received_at),
      webhook: JSON.encode!(%{hello: "world"}),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      webhook_signature: "sha256=2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae",
      webhook_raw_payload: "{\"hello\":\"world\"}"
    }

    RepositoryServiceMock
    |> GrpcMock.expect(:verify_webhook_signature, fn _, _ ->
      raise "oops"
    end)
    |> GrpcMock.expect(:verify_webhook_signature, fn _, _ ->
      %InternalApi.Repository.VerifyWebhookSignatureResponse{valid: true}
    end)

    params
    |> ReceivedWebhook.encode()
    |> Tackle.publish(options)

    :timer.sleep(500)
    assert 0 = AMQP.Queue.message_count(ctx.channel, ctx.queue)
    assert {:error, _} = HooksQueries.get_by_repo_received_at(params.repository_id, received_at)

    :timer.sleep(10_500)
    assert 0 = AMQP.Queue.message_count(ctx.channel, ctx.queue)
    AMQP.Connection.close(ctx.connection)

    assert {:ok, _} = HooksQueries.get_by_repo_received_at(params.repository_id, received_at)
    GrpcMock.verify!(RepositoryServiceMock)
  end

  def purge_queue(queue) do
    {:ok, connection} = Application.get_env(:hooks_processor, :amqp_url) |> AMQP.Connection.open()
    queue_name = "hooks_processor.#{queue}"
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Queue.declare(channel, queue_name, durable: true)

    AMQP.Queue.purge(channel, queue_name)

    {:ok, %{channel: channel, queue: queue_name, connection: connection}}
  end

  def date_time_to_timestamps(nil), do: %{seconds: 0, nanos: 0}

  def date_time_to_timestamps(date_time = %DateTime{}) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end

  def date_time_to_timestamps(value), do: value
end
