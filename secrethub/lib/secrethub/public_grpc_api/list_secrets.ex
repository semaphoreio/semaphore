defmodule Secrethub.PublicGrpcApi.ListSecrets do
  import Ecto.Query

  alias Secrethub.Repo

  @default_page_size 100
  @page_size_limit 100

  #
  # Helpers for listing secrets in the Public Grpc API

  def query(org_id, project_id, page_size, order, page_token, ignore_contents?) do
    page_token = if page_token == "", do: nil, else: page_token

    query =
      Secrethub.Secret
      |> Secrethub.Secret.in_org(org_id)
      |> Secrethub.Secret.in_project(project_id)

    page =
      case order do
        :BY_NAME_ASC ->
          query
          |> order_by([s], asc: s.name, asc: s.id)
          |> Repo.paginate(cursor_fields: [:name, :id], limit: page_size, after: page_token)

        :BY_CREATE_TIME_ASC ->
          query
          |> order_by([s], asc: s.inserted_at, asc: s.id)
          |> Repo.paginate(
            cursor_fields: [:inserted_at, :id],
            limit: page_size,
            after: page_token
          )
      end

    next_page_token = if is_nil(page.metadata.after), do: "", else: page.metadata.after

    entries =
      if ignore_contents? do
        page.entries
      else
        Enum.map(page.entries, fn e ->
          case Secrethub.Encryptor.decrypt_secret(e) do
            {:ok, secret} -> secret
            _ -> nil
          end
        end)
      end

    {:ok, entries, next_page_token}
  end

  def extract_page_size(req) do
    cond do
      req.page_size == 0 ->
        {:ok, @default_page_size}

      req.page_size > @default_page_size ->
        {:error, :precondition_failed, "Page size can't exceed #{@page_size_limit}"}

      true ->
        {:ok, req.page_size}
    end
  end
end
