defmodule Front.Models.AuditLog do
  @moduledoc """
  Audit log model
  """
  alias InternalApi.Audit, as: API
  alias InternalApi.Audit.AuditService.Stub

  defmodule S3 do
    use Ecto.Schema
    import Ecto.Changeset

    @fields ~w(bucket key_id key_secret host region type instance_role)a
    @schema_fields ~w(bucket key_id key_secret host region instance_role)a

    @primary_key false
    embedded_schema do
      field(:bucket, :string)
      field(:key_id, :string)
      field(:key_secret, :string)
      field(:host, :string)
      field(:region, :string)
      field(:instance_role, :boolean, default: false)
    end

    def empty, do: struct(__MODULE__)

    def new(params \\ []), do: struct(__MODULE__, init_params(params))

    defp init_params(params),
      do:
        Map.new(default_params())
        |> Map.merge(Map.new(params), &init_param/3)
        |> set_instance_role

    defp init_param(_key, default, provided) do
      if provided, do: provided, else: default
    end

    defp set_instance_role(params = %{type: credentials_type}) do
      case credentials_type do
        :INSTANCE_ROLE -> Map.put(params, :instance_role, true)
        _ -> Map.put(params, :instance_role, false)
      end
    end

    defp set_instance_role(params), do: Map.put(params, :instance_role, false)

    def default_params,
      do: %{bucket: "", key_id: "", key_secret: "", host: "", instance_role: false}

    @doc "Maps Protobuf API content to model (from response)"
    def from_api(stream) when is_nil(stream), do: new()

    def from_api(stream) when is_map(stream) do
      stream
      |> Map.take(@fields)
      |> new()
    end

    def to_api(model = %__MODULE__{}) do
      model
      |> set_credentials_type
      |> Map.take(@fields)
      |> Enum.filter(fn {_, v} -> v != nil end)
    end

    defp set_credentials_type(params = %__MODULE__{instance_role: true}),
      do: Map.put(params, :type, :INSTANCE_ROLE)

    defp set_credentials_type(params = %__MODULE__{}),
      do: Map.put(params, :type, :USER)

    def changeset(schema), do: change(schema)

    def changeset(schema, params) do
      validated_schema =
        schema
        |> cast(params, @schema_fields)
        |> validate_required([:bucket, :instance_role])

      if params["instance_role"] == "true",
        do: validated_schema |> validate_required([:region]),
        else: validated_schema |> validate_required([:key_id, :key_secret])
    end
  end

  def describe(org_id) do
    with {:ok, request} <- new_request(API.DescribeStreamRequest, %{org_id: org_id}),
         {:ok, response} <- grpc_call(&Stub.describe_stream/2, request) do
      {:ok, response}
    else
      # not good at all using 5 <= GRPC.Status.not_found()  :)
      {:error, %{status: 5}} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  # taken from S3.create to simplify
  def create(org_id, user_id, model) do
    call_create(%{org_id: org_id, user_id: user_id, s3_config: S3.to_api(model)})
  end

  def update(org_id, user_id, model) do
    call_update(%{org_id: org_id, user_id: user_id, s3_config: S3.to_api(model)})
  end

  def destroy(org_id) do
    call_destroy(org_id)
  end

  def set_state(org_id, user_id, state)
      when is_binary(org_id) and is_binary(user_id) and is_atom(state) do
    call_set_state(org_id, user_id, state)
  end

  def test_stream(org_id, model) do
    call_test(%{org_id: org_id, s3_config: S3.to_api(model)})
  end

  def provider(provider) when is_binary(provider) do
    case provider do
      "S3" -> {:ok, :S3}
      _ -> {:error, "not recognised provider"}
    end
  end

  defp call_set_state(org_id, user_id, state) do
    require Logger

    with {:ok, request} <-
           new_request(API.SetStreamStateRequest, %{
             org_id: org_id,
             user_id: user_id,
             status: API.StreamStatus.value(state)
           }),
         {:ok, _response} <- grpc_call(&Stub.set_stream_state/2, request) do
      {:ok, nil}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp call_destroy(org_id) do
    with {:ok, request} <- new_request(API.DestroyStreamRequest, %{org_id: org_id}),
         {:ok, response} <- grpc_call(&Stub.destroy_stream/2, request) do
      {:ok, response}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  defp call_create(params) do
    watch("audit_log.stream.create", fn ->
      with {:ok, request} <-
             new_request(API.CreateStreamRequest, %{
               stream: %{org_id: params.org_id, provider: :S3, s3_config: params.s3_config},
               user_id: params.user_id
             }),
           {:ok, response} <- grpc_call(&Stub.create_stream/2, request) do
        {:ok, response.stream}
      else
        {:error, error} -> {:error, error}
      end
    end)
  end

  defp call_update(params) do
    watch("audit_log.stream.update", fn ->
      with {:ok, request} <-
             new_request(API.UpdateStreamRequest, %{
               stream: %{org_id: params.org_id, provider: :S3, s3_config: params.s3_config},
               user_id: params.user_id
             }),
           {:ok, response} <- grpc_call(&Stub.update_stream/2, request) do
        {:ok, response.stream}
      else
        {:error, error} -> {:error, error}
      end
    end)
  end

  def call_test(params) do
    watch("audit_log.stream.test", fn ->
      with {:ok, request} <-
             new_request(API.TestStreamRequest, %{
               stream: %{org_id: params.org_id, provider: :S3, s3_config: params.s3_config}
             }),
           {:ok, response} <- grpc_call(&Stub.test_stream/2, request) do
        {:ok, response}
      else
        {:error, error} -> {:error, error}
      end
    end)
  end

  def get_changeset(stream, provider) when is_nil(stream) do
    case provider do
      :S3 -> {:new, S3.changeset(S3.new())}
    end
  end

  def get_changeset(stream, provider) do
    if stream.provider == provider do
      {:matching_provider, from_response(stream)}
    else
      {:already_exists, stream.provider, from_response(stream)}
    end
  end

  defp from_response(stream) do
    case stream.provider do
      :S3 ->
        S3.changeset(S3.from_api(stream.s3_config))
    end
  end

  defp grpc_call(func, request) do
    endpoint = Application.fetch_env!(:front, :audit_grpc_endpoint)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, response} <- func.(channel, request) do
      Util.Proto.to_map(response)
    else
      {:error, _reason} = error -> error
    end
  end

  def new_request(request_module, params) do
    # case params.provider do
    #   :S3 -> Map.new(params) |> Map.put(:)
    # end
    Map.new(params) |> Util.Proto.deep_new(request_module)
  end

  defp watch(prefix_key, request_fn) do
    response = Watchman.benchmark("#{prefix_key}.duration", request_fn)
    Watchman.increment(counted_key(prefix_key, response))
    response
  end

  defp counted_key(prefix, :ok), do: "#{prefix}.success"
  defp counted_key(prefix, {:ok, _}), do: "#{prefix}.success"
  defp counted_key(prefix, {:error, %{code: :NOT_FOUND}}), do: "#{prefix}.success"
  defp counted_key(prefix, {:error, _}), do: "#{prefix}.failure"
end
