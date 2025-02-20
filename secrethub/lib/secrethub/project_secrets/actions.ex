defmodule Secrethub.ProjectSecrets.Actions do
  alias InternalApi.Secrethub, as: API
  require Logger

  alias Secrethub.ProjectSecrets.Store
  alias Secrethub.ProjectSecrets.Secret
  alias Secrethub.ProjectSecrets.Mapper

  @page_size_limit 100

  def handle_list_keyset(request),
    do: handle(&list_keyset/1, request, API.ListKeysetResponse)

  def handle_describe(request),
    do: handle(&describe/1, request, API.DescribeResponse)

  def handle_describe_many(request),
    do: describe_many(request)

  def handle_destroy(request),
    do: handle(&destroy/1, request, API.DestroyResponse)

  def handle_create(request),
    do: handle(&create/1, request, API.CreateResponse)

  def handle_update(request),
    do: handle(&update/1, request, API.UpdateResponse)

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
    if empty?(request.project_id) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing data: project_id"
    end

    case Store.list_by_project_id(request.project_id, request.ignore_contents) do
      {:ok, secrets} ->
        API.ListKeysetResponse.new(
          metadata: response_meta(request.metadata),
          secrets: Mapper.encode(secrets)
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
      message: "Project level secret API does not implement describe_many"
  end

  def describe(request = %API.DescribeRequest{metadata: req_meta}) do
    result =
      cond do
        not empty?(request.id) and not empty?(request.project_id) ->
          Store.find_by_id(req_meta.org_id, request.project_id, request.id)

        not empty?(request.name) and not empty?(request.project_id) ->
          Store.find_by_name(req_meta.org_id, request.project_id, request.name)

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

  def create(%API.CreateRequest{secret: nil}) do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "secret must be provided"
  end

  def create(request = %API.CreateRequest{}) do
    case Store.create(Mapper.decode(request.secret)) do
      {:ok, secret} ->
        API.CreateResponse.new(
          metadata: response_meta(request.metadata),
          secret: Mapper.encode(secret)
        )

      {:error, reason} ->
        raise_error(reason)
    end
  end

  def update(%API.UpdateRequest{secret: nil}) do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "secret must be provided"
  end

  def update(%API.UpdateRequest{secret: %API.Secret{metadata: %API.Secret.Metadata{id: id}}})
      when id == nil or id == "" do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "secret.metadata.id must be provided"
  end

  def update(request = %API.UpdateRequest{}) do
    with {:ok, secret} <-
           Store.find_by_id(
             request.metadata.org_id,
             request.secret.project_config.project_id,
             request.secret.metadata.id
           ),
         {:ok, secret} <- Store.update(secret, Mapper.decode(request.secret)) do
      API.UpdateResponse.new(
        metadata: response_meta(request.metadata),
        secret: Mapper.encode(secret)
      )
    else
      {:error, reason} ->
        raise_error(reason)
    end
  end

  def destroy(_request = %API.DestroyRequest{metadata: nil}) do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "Missing request metadata"
  end

  def destroy(request = %API.DestroyRequest{}) do
    secret_lookup =
      cond do
        not empty?(request.id) and not empty?(request.project_id) ->
          Store.find_by_id(request.metadata.org_id, request.project_id, request.id)

        not empty?(request.name) and not empty?(request.project_id) ->
          Store.find_by_name(request.metadata.org_id, request.project_id, request.name)

        true ->
          {:error, :missing_lookup_args}
      end

    with {:ok, secret} <- secret_lookup,
         {:ok, _secret} <- Store.delete(secret) do
      API.DestroyResponse.new(metadata: response_meta(request.metadata), id: secret.id)
    else
      {:error, reason} -> raise_error(reason, project_id: request.project_id)
    end
  end

  # helpers

  defp empty?(string) when is_binary(string),
    do: string |> String.trim() |> String.equivalent?("")

  # handling response

  defp handle(_handle_fun, %{metadata: req_meta}, _response_module)
       when is_nil(req_meta) or req_meta.org_id == nil or req_meta.org_id == "" do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "Missing org_id in request metadata"
  end

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
    Logger.debug(fn -> "[Project level] Secret not found: #{inspect(extra)}" end)

    raise GRPC.RPCError,
      status: :not_found,
      message: "secret not found"
  end

  defp raise_error(:missing_lookup_args, extra) do
    Logger.debug(fn -> "[Project level] Missing arguments: #{inspect(extra)}" end)

    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "Missing lookup argument"
  end

  defp raise_error(changeset = %Ecto.Changeset{}, extra) do
    Logger.debug(fn -> "[Project level] #{inspect(changeset)}: #{inspect(extra)}" end)

    raise GRPC.RPCError,
      status: :invalid_argument,
      message: format_error_message(changeset.errors)
  end

  defp format_error_message([{field, {msg, opts}} | _]) do
    Atom.to_string(field) <>
      ": " <>
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
  end
end
