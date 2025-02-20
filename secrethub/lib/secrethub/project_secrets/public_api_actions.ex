defmodule Secrethub.ProjectSecrets.PublicAPIActions do
  alias Semaphore.ProjectSecrets.V1, as: API
  require Logger

  alias Secrethub.ProjectSecrets.Store
  alias Secrethub.ProjectSecrets.Secret
  alias Secrethub.ProjectSecrets.PublicAPIMapper, as: Mapper

  @page_size_limit 100
  # implementation

  def list_secrets(%API.ListSecretsRequest{page_size: page_size}, _)
      when page_size > @page_size_limit do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "Page size can't exceed #{@page_size_limit}"
  end

  def list_secrets(request = %API.ListSecretsRequest{}, ctx) do
    if empty?(request.project_id_or_name) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing data: project_id_or_name"
    end

    project_id = request.project_id_or_name

    with {:ok, page_size} <- Secrethub.PublicGrpcApi.ListSecrets.extract_page_size(request),
         {:ok, secrets, next_page_token} <-
           Store.paginate_by_project_id(project_id, page_size, request.page_token) do
      API.ListSecretsResponse.new(
        next_page_token: next_page_token,
        secrets: Mapper.encode(secrets, ctx.render_content)
      )
    else
      {:error, :not_found} ->
        API.ListSecretsResponse.new(secrets: [])
    end
  end

  def get_secret(request = %API.GetSecretRequest{}, ctx) do
    result = secret_lookup(request.project_id_or_name, request.secret_id_or_name, ctx)

    case result do
      {:ok, secret = %Secret{}} ->
        Mapper.encode(secret, ctx.render_content)

      {:error, reason} ->
        raise_error(reason)
    end
  end

  def create_secret(request = %API.Secret{}, ctx) do
    secret = Mapper.decode(request, ctx)
    secret = Map.put(secret, :created_by, ctx.user_id)
    secret = Map.put(secret, :updated_by, ctx.user_id)

    case Store.create(secret) do
      {:ok, secret} ->
        Mapper.encode(secret, ctx.render_content)

      {:error, reason} ->
        raise_error(reason)
    end
  end

  def update_secret(%API.UpdateSecretRequest{secret: nil}, _) do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "secret must be provided"
  end

  def update_secret(%API.UpdateSecretRequest{secret_id_or_name: id}, _)
      when id == nil or id == "" do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "secret.secret_id_or_name must be provided"
  end

  def update_secret(request = %API.UpdateSecretRequest{}, ctx) do
    new_secret = Mapper.decode(request.secret, ctx)
    new_secret = Map.put(new_secret, :updated_by, ctx.user_id)

    with {:ok, true} <- updateable?(ctx),
         {:ok, secret} <-
           secret_lookup(request.project_id_or_name, request.secret_id_or_name, ctx),
         {:ok, secret} <- Store.update(secret, new_secret) do
      Mapper.encode(secret, ctx.render_content)
    else
      {:error, reason} ->
        raise_error(reason)
    end
  end

  def delete_secret(%API.DeleteSecretRequest{secret_id_or_name: id}, _)
      when id == nil or id == "" do
    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "Missing lookup argument"
  end

  def delete_secret(request = %API.DeleteSecretRequest{}, params) do
    with {:ok, secret} <-
           secret_lookup(request.project_id_or_name, request.secret_id_or_name, params),
         {:ok, _secret} <- Store.delete(secret) do
      API.Empty.new()
    else
      {:error, reason} -> raise_error(reason, project_id: request.project_id_or_name)
    end
  end

  # helpers

  defp empty?(string) when is_binary(string),
    do: string |> String.trim() |> String.equivalent?("")

  defp updateable?(%{render_content: true}), do: {:ok, true}
  defp updateable?(%{render_content: false}), do: {:error, :content_not_rendered}
  # handling response

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

  defp raise_error(:project_not_found, extra) do
    Logger.debug(fn -> "[Project level] Project not found: #{inspect(extra)}" end)

    raise GRPC.RPCError,
      status: :invalid_argument,
      message: "Project that you provided does not exist"
  end

  defp raise_error(:content_not_rendered, _) do
    Logger.debug(fn -> "[Project level] Secret modification restricted" end)

    raise GRPC.RPCError,
      status: :failed_precondition,
      message: "Secret can not be updated with API"
  end

  defp raise_error(changeset = %Ecto.Changeset{}, extra) do
    Logger.debug(fn -> "[Project level] #{inspect(changeset)}: #{inspect(extra)}" end)

    raise GRPC.RPCError,
      status: :invalid_argument,
      message: print_error(changeset.errors)
  end

  defp print_error(errors) do
    Enum.map_join(errors, ", ", fn {field, {msg, opts}} ->
      Atom.to_string(field) <>
        ": " <>
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
    end)
  end

  defp uuid?(string) do
    case Ecto.UUID.cast(string) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp secret_lookup(project_id, secret_id_or_name, params) do
    cond do
      not empty?(secret_id_or_name) and uuid?(secret_id_or_name) and not empty?(project_id) ->
        Store.find_by_id(params.org_id, project_id, secret_id_or_name)

      not empty?(secret_id_or_name) and not empty?(project_id) ->
        Store.find_by_name(params.org_id, project_id, secret_id_or_name)

      true ->
        {:error, :missing_lookup_args}
    end
  end
end
