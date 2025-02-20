defmodule Gofer.SecrethubClient.Test do
  use ExUnit.Case, async: false
  alias InternalApi.Secrethub, as: API
  alias Gofer.SecrethubClient

  @mock_port 52_051

  setup_all [
    :start_grpc,
    :general_args,
    :secret_creds,
    :secret_content,
    :form_args
  ]

  @args ~w(
    organization_id user_id target_id secret_id secret_name
    key_id aes256_key init_vector payload
  )a

  describe "invalid URL tests" do
    setup do
      old_config = Application.get_env(:gofer, SecrethubClient, [])
      new_config = Keyword.put(old_config, :endpoint, "invalid:49999")
      new_config = Keyword.put(new_config, :timeout, 1_000)

      Application.put_env(:gofer, SecrethubClient, new_config)
      on_exit(fn -> Application.put_env(:gofer, SecrethubClient, old_config) end)
    end

    @tag capture_log: true
    test "create/1 when URL is invalid then returns error", ctx do
      assert {:error, {:timeout, 1_000}} = SecrethubClient.create(ctx[:args])
    end

    @tag capture_log: true
    test "update/1 when URL is invalid then returns error", ctx do
      assert {:error, {:timeout, 1_000}} = SecrethubClient.update(ctx[:args])
    end

    @tag capture_log: true
    test "delete/1 when URL is invalid then returns error", ctx do
      assert {:error, {:timeout, 1_000}} = SecrethubClient.delete(ctx[:args])
    end
  end

  describe "timeout tests" do
    setup do
      old_config = Application.get_env(:gofer, SecrethubClient, [])
      new_config = Keyword.put(old_config, :timeout, 1_000)
      Application.put_env(:gofer, SecrethubClient, new_config)
      on_exit(fn -> Application.put_env(:gofer, SecrethubClient, old_config) end)
    end

    @tag capture_log: true
    test "create/1 when timeout occurs then returns error", ctx do
      mock_create(1, true)

      assert {:error, {:timeout, 1_000}} = SecrethubClient.create(ctx[:args])
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end

    @tag capture_log: true
    test "update/1 when timeout occurs then returns error", ctx do
      mock_update(1, true)

      assert {:error, {:timeout, 1_000}} = SecrethubClient.update(ctx[:args])
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end

    @tag capture_log: true
    test "delete/1 when timeout occurs then returns error", ctx do
      mock_delete(1, true)

      assert {:error, {:timeout, 1_000}} = SecrethubClient.delete(ctx[:args])
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end
  end

  describe "create/1" do
    setup do
      [required_args: ~w(
        organization_id user_id target_id secret_name
        key_id aes256_key init_vector payload
      )a]
    end

    test "without necessary values raises error", ctx do
      for value <- ctx[:required_args] do
        assert {:error, {:shutdown, {%RuntimeError{message: "Missing value: " <> _}, []}}} =
                 SecrethubClient.create(Keyword.delete(ctx[:args], value))
      end
    end

    test "without unnecessary values returns ok", ctx do
      args = @args -- ctx[:required_args]
      mock_create(length(args))

      for value <- args do
        assert {:ok, _} = SecrethubClient.create(Keyword.delete(ctx[:args], value))
      end

      assert :ok = GrpcMock.verify!(SecrethubMock)
    end

    test "with minimal set of values creates a successful call", ctx = %{secret_name: name} do
      secret_id = mock_create()
      args = ctx |> Map.take(ctx[:required_args]) |> Map.to_list()

      assert {:ok, %{secret_id: ^secret_id, secret_name: ^name}} = SecrethubClient.create(args)
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end

    test "with minimal set of values meets metadata", ctx = %{secret_name: name} do
      secret_id = mock_create()

      args =
        ctx
        |> Map.take(ctx[:required_args])
        |> Map.put(:request_id, UUID.uuid4())
        |> Map.to_list()

      assert {:ok, %{secret_id: ^secret_id, secret_name: ^name}} = SecrethubClient.create(args)
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end
  end

  describe "update/1" do
    setup do
      [required_args: ~w(
        organization_id user_id target_id secret_id secret_name
        key_id aes256_key init_vector payload
      )a]
    end

    test "without necessary values raises error", ctx do
      for value <- ctx[:required_args] do
        assert {:error, {:shutdown, {%RuntimeError{message: "Missing value: " <> _}, []}}} =
                 SecrethubClient.update(Keyword.delete(ctx[:args], value))
      end
    end

    test "without unnecessary values returns ok", ctx do
      args = @args -- ctx[:required_args]
      mock_update(length(args))

      for value <- args do
        assert {:ok, _} = SecrethubClient.update(Keyword.delete(ctx[:args], value))
      end

      assert :ok = GrpcMock.verify!(SecrethubMock)
    end

    test "with minimal set of values creates a successful call",
         ctx = %{secret_id: id, secret_name: name} do
      mock_update()
      args = ctx |> Map.take(ctx[:required_args]) |> Map.to_list()

      assert {:ok, %{secret_id: ^id, secret_name: ^name}} = SecrethubClient.update(args)
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end

    test "with minimal set of values meets metadata",
         ctx = %{secret_id: id, secret_name: name} do
      mock_update()

      args =
        ctx
        |> Map.take(ctx[:required_args])
        |> Map.put(:request_id, UUID.uuid4())
        |> Map.to_list()

      assert {:ok, %{secret_id: ^id, secret_name: ^name}} = SecrethubClient.update(args)
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end
  end

  describe "delete/1" do
    setup do
      [required_args: ~w(organization_id user_id target_id secret_id secret_name)a]
    end

    test "without necessary values returns error", ctx do
      for value <- ctx[:required_args] do
        assert {:error, {:shutdown, {%RuntimeError{message: "Missing value: " <> _}, []}}} =
                 SecrethubClient.delete(Keyword.delete(ctx[:args], value))
      end
    end

    test "without unnecessary values returns ok", ctx do
      args = @args -- ctx[:required_args]
      mock_delete(length(args))

      for value <- args do
        assert {:ok, _} = SecrethubClient.delete(Keyword.delete(ctx[:args], value))
      end

      assert :ok = GrpcMock.verify!(SecrethubMock)
    end

    test "with minimal set of values creates a successful call",
         ctx = %{secret_id: id, secret_name: name} do
      mock_delete()

      args = ctx |> Map.take(ctx[:required_args]) |> Map.to_list()
      assert {:ok, %{secret_id: ^id, secret_name: ^name}} = SecrethubClient.delete(args)
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end

    test "when secret does not exist then returns successfully",
         ctx = %{secret_id: id, secret_name: name} do
      GrpcMock.expect(SecrethubMock, :destroy, fn request, _stream ->
        API.DestroyResponse.new(
          metadata:
            response_meta(request.metadata)
            |> Map.put(
              :status,
              API.ResponseMeta.Status.new(
                code: :NOT_FOUND,
                message: "secret not found"
              )
            )
        )
      end)

      args = ctx |> Map.take(ctx[:required_args]) |> Map.to_list()
      assert {:ok, %{secret_id: ^id, secret_name: ^name}} = SecrethubClient.delete(args)
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end

    test "with minimal set of values meets metadata",
         ctx = %{secret_id: id, secret_name: name} do
      mock_delete()

      args =
        ctx
        |> Map.take(ctx[:required_args])
        |> Map.put(:request_id, UUID.uuid4())
        |> Map.to_list()

      assert {:ok, %{secret_id: ^id, secret_name: ^name}} = SecrethubClient.delete(args)
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end
  end

  defp start_grpc(_ctx) do
    GRPC.Server.start(SecrethubMock, @mock_port)

    on_exit(fn ->
      GRPC.Server.stop(SecrethubMock)
    end)
  end

  defp general_args(_ctx),
    do: [organization_id: UUID.uuid4(), user_id: UUID.uuid4()]

  defp secret_creds(_ctx),
    do: [target_id: UUID.uuid4(), secret_id: UUID.uuid4(), secret_name: "Production"]

  defp secret_content(_ctx) do
    content = [
      key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
      aes256_key: random_payload(256),
      init_vector: random_payload(256),
      payload: random_payload()
    ]

    encrypted_content = InternalApi.Secrethub.EncryptedData.new(content)

    {:ok, Keyword.put(content, :content, encrypted_content)}
  end

  defp form_args(ctx), do: [args: ctx |> Map.take(@args) |> Map.to_list()]

  defp random_payload(n_bytes \\ 1_024),
    do: round(n_bytes) |> :crypto.strong_rand_bytes() |> Base.encode64()

  defp mock_create(times \\ 1, wait \\ false) do
    secret_id = UUID.uuid4()

    GrpcMock.expect(SecrethubMock, :create_encrypted, times, fn request, _stream ->
      if wait, do: Process.sleep(3_000)

      API.CreateEncryptedResponse.new(
        metadata: response_meta(request.metadata),
        secret: request.secret |> Map.update!(:metadata, &Map.put(&1, :id, secret_id)),
        encrypted_data: request.encrypted_data
      )
    end)

    on_exit(fn ->
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end)

    secret_id
  end

  defp mock_update(times \\ 1, wait \\ false) do
    GrpcMock.expect(SecrethubMock, :update_encrypted, times, fn request, _stream ->
      if wait, do: Process.sleep(3_000)

      API.UpdateEncryptedResponse.new(
        metadata: response_meta(request.metadata),
        secret: request.secret,
        encrypted_data: request.encrypted_data
      )
    end)

    on_exit(fn ->
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end)
  end

  defp mock_delete(times \\ 1, wait \\ false) do
    GrpcMock.expect(SecrethubMock, :destroy, times, fn request, _stream ->
      if wait, do: Process.sleep(3_000)

      API.DestroyResponse.new(metadata: response_meta(request.metadata))
    end)

    on_exit(fn ->
      assert :ok = GrpcMock.verify!(SecrethubMock)
    end)
  end

  defp response_meta(metadata = %API.RequestMeta{}) do
    metadata
    |> Map.take(~w(api_version kind req_id org_id user_id)a)
    |> Map.put(:status, API.ResponseMeta.Status.new(code: :OK))
    |> Enum.to_list()
    |> API.ResponseMeta.new()
  end
end
