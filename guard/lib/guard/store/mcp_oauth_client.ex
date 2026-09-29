defmodule Guard.Store.McpOAuthClient do
  @moduledoc """
  Store module for MCP OAuth client operations.
  Manages OAuth clients registered via Dynamic Client Registration (DCR).
  """

  require Logger
  import Ecto.Query

  alias Guard.Repo
  alias Guard.Repo.McpOAuthClient

  @doc """
  Find an OAuth client by client_id.
  """
  @spec find_by_client_id(String.t()) :: {:ok, McpOAuthClient.t()} | {:error, :not_found}
  def find_by_client_id(client_id) when is_binary(client_id) do
    query = from(c in McpOAuthClient, where: c.client_id == ^client_id)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      client -> {:ok, client}
    end
  end

  @doc """
  Create a new OAuth client.

  Expects params map with:
  - client_id (required)
  - client_name (optional)
  - redirect_uris (required, list of URIs)
  """
  @spec create(map()) :: {:ok, McpOAuthClient.t()} | {:error, term()}
  def create(params) do
    changeset = McpOAuthClient.changeset(%McpOAuthClient{}, params)

    case Repo.insert(changeset) do
      {:ok, client} -> {:ok, client}
      {:error, changeset} -> {:error, changeset}
    end
  rescue
    e ->
      Logger.error("Error creating MCP OAuth client: #{inspect(e)}")
      {:error, :internal_error}
  end

  @doc """
  Check if a redirect_uri is valid for a client.
  """
  @spec valid_redirect_uri?(McpOAuthClient.t(), String.t()) :: boolean()
  def valid_redirect_uri?(%McpOAuthClient{redirect_uris: uris}, redirect_uri) do
    redirect_uri in uris
  end
end
