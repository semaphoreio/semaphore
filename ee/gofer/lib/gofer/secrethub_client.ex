defmodule Gofer.SecrethubClient do
  @moduledoc """
  gRPC client consuming SecretHub API

  Each deployment has exactly one secret (so-called deployment-target secret),
  which is injected into promoted pipeline. Those secrets are accessible only
  within that promotion.
  Deployment configuration is handled by gofer, which delegates the responsibility
  to create/update/delete secrets to secrethub and synchronizes the state of target
  based on the response from secrethub. This client serves as a communication
  point between gofer and secrethub.
  """

  alias InternalApi.Secrethub, as: API
  alias API.ResponseMeta.Status

  # for some reason Dialyzer produces a pointless type mismatch for parse_response/3
  @dialyzer {:nowarn_function, parse_response: 3}

  @metric_prefix "Gofer.deployments.secrets"
  @default_timeout 5_000

  defp config, do: Application.get_env(:gofer, __MODULE__)

  def create(args), do: grpc_call(:create, args)
  def update(args), do: grpc_call(:update, args)
  def delete(args), do: grpc_call(:delete, args)

  # forming request

  defp form_request(:create, args) do
    args = Keyword.put(args, :created_by, args[:user_id])

    API.CreateEncryptedRequest.new(
      metadata: metadata_from_args(args),
      secret: secret_from_args(args, ""),
      encrypted_data: data_from_args(args)
    )
  end

  defp form_request(:update, args) do
    API.UpdateEncryptedRequest.new(
      metadata: metadata_from_args(args),
      secret: secret_from_args(args, from_args!(args, :secret_id)),
      encrypted_data: data_from_args(args)
    )
  end

  defp form_request(:delete, args) do
    API.DestroyRequest.new(
      metadata: metadata_from_args(args),
      id: from_args!(args, :secret_id),
      name: from_args!(args, :secret_name),
      secret_level: :DEPLOYMENT_TARGET,
      deployment_target_id: from_args!(args, :target_id)
    )
  end

  defp metadata_from_args(args) do
    API.RequestMeta.new(
      api_version: "v1alpha",
      kind: "Secret",
      req_id: Access.get(args, :request_id, UUID.uuid4()),
      org_id: from_args!(args, :organization_id),
      user_id: from_args!(args, :user_id)
    )
  end

  defp secret_from_args(args, secret_id) do
    API.Secret.new(
      metadata:
        API.Secret.Metadata.new(
          id: secret_id,
          name: from_args!(args, :secret_name),
          org_id: from_args!(args, :organization_id),
          level: :DEPLOYMENT_TARGET,
          created_by: from_args(args, :created_by),
          updated_by: from_args!(args, :user_id)
        ),
      dt_config: API.Secret.DTConfig.new(deployment_target_id: from_args!(args, :target_id))
    )
  end

  defp data_from_args(args) do
    ~w(key_id aes256_key init_vector payload)a
    |> Enum.into([], &{&1, from_args!(args, &1)})
    |> API.EncryptedData.new()
  end

  defp from_args(args, key), do: args[key] || ""
  defp from_args!(args, key), do: args[key] || raise("Missing value: #{key}")

  # gRPC request

  def grpc_call(request_type, args) do
    result =
      Watchman.benchmark(duration_metric(request_type), fn ->
        Wormhole.capture(__MODULE__, :do_grpc_call, [request_type, args],
          timeout: config()[:timeout] || @default_timeout,
          stacktrace: true
        )
      end)

    case result do
      {:ok, {:ok, result}} ->
        Watchman.increment(success_metric(request_type))
        {:ok, result}

      {:ok, {:error, reason}} ->
        Watchman.increment(failure_metric(request_type))
        {:error, reason}

      error ->
        Watchman.increment(failure_metric(request_type))
        error
    end
  end

  def do_grpc_call(request_type, args) do
    request = form_request(request_type, args)
    func = grpc_for_request(request)

    with {:ok, channel} <- GRPC.Stub.connect(config()[:endpoint]),
         {:ok, response} <- grpc_send(channel, func, request) do
      parse_response(response.metadata.status, request, response)
    else
      {:error, _reason} = error -> error
    end
  end

  defp grpc_send(channel, func, request),
    do: func.(channel, request),
    after: GRPC.Stub.disconnect(channel)

  defp grpc_for_request(%API.CreateEncryptedRequest{}),
    do: &API.SecretService.Stub.create_encrypted/2

  defp grpc_for_request(%API.UpdateEncryptedRequest{}),
    do: &API.SecretService.Stub.update_encrypted/2

  defp grpc_for_request(%API.DestroyRequest{}),
    do: &API.SecretService.Stub.destroy/2

  # parsing response

  defp parse_response(%Status{code: :OK}, _request, %API.CreateEncryptedResponse{secret: secret}),
    do: {:ok, %{secret_id: secret.metadata.id, secret_name: secret.metadata.name}}

  defp parse_response(%Status{code: :OK}, _request, %API.UpdateEncryptedResponse{secret: secret}),
    do: {:ok, %{secret_id: secret.metadata.id, secret_name: secret.metadata.name}}

  defp parse_response(%Status{code: :OK}, request = %API.DestroyRequest{}, _response),
    do: {:ok, %{secret_id: request.id, secret_name: request.name}}

  defp parse_response(%Status{code: :NOT_FOUND}, request = %API.DestroyRequest{}, _response),
    do: {:ok, %{secret_id: request.id, secret_name: request.name}}

  defp parse_response(status = %Status{}, _request, _response),
    do: {:error, Map.drop(status, [:__struct__, :__unknown_fields__])}

  defp duration_metric(request_type), do: "#{@metric_prefix}.#{request_type}"
  defp success_metric(request_type), do: "#{@metric_prefix}.#{request_type}.success"
  defp failure_metric(request_type), do: "#{@metric_prefix}.#{request_type}.failure"
end
