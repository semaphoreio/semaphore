defmodule Secrethub.DeploymentTargets.Actions do
  alias InternalApi.Secrethub, as: API
  alias Secrethub.KeyVault
  require Logger

  alias Secrethub.DeploymentTargets.Store
  alias Secrethub.DeploymentTargets.Secret
  alias Secrethub.DeploymentTargets.Mapper

  @page_size_limit 100

  def handle_list_keyset(request),
    do: handle(&list_keyset/1, request, API.ListKeysetResponse)

  def handle_describe(request),
    do: handle(&describe/1, request, API.DescribeResponse)

  def handle_describe_many(request),
    do: describe_many(request)

  def handle_create_encrypted(request),
    do: handle(&create_encrypted/1, request, API.CreateEncryptedResponse)

  def handle_update_encrypted(request),
    do: handle(&update_encrypted/1, request, API.UpdateEncryptedResponse)

  def handle_destroy(request),
    do: handle(&destroy/1, request, API.DestroyResponse)

  # implementation

  def list_keyset(%API.ListKeysetRequest{page_size: page_size})
      when page_size > @page_size_limit do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "Page size can't exceed #{@page_size_limit}"
  end

  def list_keyset(request = %API.ListKeysetRequest{page_size: 0}) do
    API.ListKeysetResponse.new(metadata: response_meta(request.metadata))
  end

  def list_keyset(request = %API.ListKeysetRequest{}) do
    if empty?(request.deployment_target_id) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing data: deployment_target_id"
    end

    case Store.find_by_target(request.deployment_target_id) do
      {:ok, secret = %Secret{}} ->
        API.ListKeysetResponse.new(
          metadata: response_meta(request.metadata),
          secrets: [Mapper.encode(secret)]
        )

      {:error, :not_found} ->
        API.ListKeysetResponse.new(
          metadata: response_meta(request.metadata),
          secrets: []
        )
    end
  end

  def describe_many(%API.DescribeManyRequest{}) do
    raise GRPC.RPCError,
      status: :unimplemented,
      message: "DT secret API does not implement describe_many"
  end

  def describe(%API.DescribeRequest{metadata: nil}) do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "Missing request metadata"
  end

  def describe(request = %API.DescribeRequest{metadata: req_meta}) do
    if empty?(req_meta.org_id) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing argument: metadata.org_id"
    end

    result =
      cond do
        not empty?(request.id) ->
          Store.find_by_id(req_meta.org_id, :skip, request.id)

        not empty?(request.name) ->
          Store.find_by_name(req_meta.org_id, request.name)

        not empty?(request.deployment_target_id) ->
          Store.find_by_target(request.deployment_target_id)

        true ->
          {:error, :missing_lookup_args}
      end

    case result do
      {:ok, secret = %Secret{}} ->
        API.DescribeResponse.new(
          metadata: response_meta(req_meta),
          secret: Mapper.encode(secret)
        )

      {:error, reason} ->
        raise_error(reason)
    end
  end

  def create_encrypted(%API.CreateEncryptedRequest{secret: nil}) do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "secret must be provided"
  end

  def create_encrypted(%API.CreateEncryptedRequest{encrypted_data: nil}) do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "encrypted_data must be provided"
  end

  def create_encrypted(request = %API.CreateEncryptedRequest{}) do
    key_id = request.encrypted_data && request.encrypted_data.key_id

    with {:ok, decrypted_data} <- KeyVault.decrypt(request.encrypted_data),
         {:ok, secret} <- Store.create(to_params(request.secret, decrypted_data)),
         {:ok, encrypted_data} <- encrypt_data(secret, key_id) do
      API.CreateEncryptedResponse.new(
        metadata: response_meta(request.metadata),
        secret: from_model(secret),
        encrypted_data: encrypted_data
      )
    else
      {:error, reason} ->
        raise_error(reason)
    end
  end

  def update_encrypted(%API.UpdateEncryptedRequest{secret: nil}) do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "secret must be provided"
  end

  def update_encrypted(%API.UpdateEncryptedRequest{encrypted_data: nil}) do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "encrypted_data must be provided"
  end

  def update_encrypted(request = %API.UpdateEncryptedRequest{}) do
    key_id = request.encrypted_data && request.encrypted_data.key_id

    with {:ok, secret} <- Store.find_by_target(request.secret.dt_config.deployment_target_id),
         {:ok, decrypted_data} <- KeyVault.decrypt(request.encrypted_data),
         {:ok, secret} <- Store.update(secret, to_params(request.secret, decrypted_data)),
         {:ok, encrypted_data} <- encrypt_data(secret, key_id) do
      API.UpdateEncryptedResponse.new(
        metadata: response_meta(request.metadata),
        secret: from_model(secret),
        encrypted_data: encrypted_data
      )
    else
      {:error, reason} ->
        raise_error(reason)
    end
  end

  def destroy(request = %API.DestroyRequest{}) do
    if empty?(request.deployment_target_id) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "deployment_target_id must be provided"
    end

    dt_id = request.deployment_target_id

    with {:ok, secret} <- Store.find_by_target(dt_id),
         {:ok, _secret} <- Store.delete(secret) do
      API.DestroyResponse.new(metadata: response_meta(request.metadata), id: secret.id)
    else
      {:error, reason} -> raise_error(reason, dt_id: dt_id)
    end
  end

  # helpers

  defp encrypt_data(secret, key_id),
    do: secret.content |> Mapper.encode() |> KeyVault.encrypt(key_id)

  defp from_model(secret),
    do: %API.Secret{Mapper.encode(secret) | data: nil}

  defp to_params(secret, decrypted_data),
    do: Mapper.decode(%API.Secret{secret | data: decrypted_data})

  defp empty?(string) when is_binary(string),
    do: string |> String.trim() |> String.equivalent?("")

  # handling response

  defp handle(handle_fun, request, response_module) do
    handle_fun.(request)
  rescue
    error in GRPC.RPCError ->
      response_module.new(metadata: response_meta(request.metadata, error))
  end

  defp response_meta(nil),
    do: API.ResponseMeta.new(status: ok_status())

  defp response_meta(req_meta = %API.RequestMeta{}) do
    req_meta
    |> Map.from_struct()
    |> Map.put(:status, ok_status())
    |> API.ResponseMeta.new()
  end

  defp response_meta(req_meta, error = %GRPC.RPCError{}) do
    req_meta
    |> response_meta()
    |> Map.put(:status, error_status(error))
  end

  defp ok_status,
    do: API.ResponseMeta.Status.new(code: :OK)

  defp error_status(%GRPC.RPCError{status: 5, message: message}),
    do: API.ResponseMeta.Status.new(code: :NOT_FOUND, message: message)

  defp error_status(%GRPC.RPCError{message: message}),
    do: API.ResponseMeta.Status.new(code: :FAILED_PRECONDITION, message: message)

  defp raise_error(reason, extra \\ [])

  defp raise_error(:not_found, extra) do
    Logger.debug(fn -> "[DT] Secret not found: #{inspect(extra)}" end)

    raise GRPC.RPCError,
      status: :not_found,
      message: "secret not found"
  end

  defp raise_error(:missing_lookup_args, extra) do
    Logger.debug(fn -> "[DT] Missing arguments: #{inspect(extra)}" end)

    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "Missing lookup argument"
  end

  defp raise_error(changeset = %Ecto.Changeset{}, extra) do
    Logger.debug(fn -> "[DT] #{inspect(changeset)}: #{inspect(extra)}" end)

    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "invalid data"
  end

  defp raise_error(error = %KeyVault.Error{}, extra) do
    Logger.error(fn -> "[DT] #{inspect(error)}: #{inspect(extra)}" end)

    raise GRPC.RPCError,
      status: :data_loss,
      message: KeyVault.Error.external_message(error)
  end
end
