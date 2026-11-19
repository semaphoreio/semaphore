defmodule Guard.Store.McpOAuthClient do
  @moduledoc """
  Store module for MCP OAuth client operations.
  Manages OAuth clients registered via Dynamic Client Registration (DCR), and
  finds those Client ID Metadata Documents describe.
  """

  require Logger
  import Ecto.Query

  alias Guard.McpOAuth.{ClientDocument, Computers}
  alias Guard.Repo
  alias Guard.Repo.McpOAuthClient

  @doc """
  Find an OAuth client by client_id: semaphore.computer's configured client, one
  a Client ID Metadata Document describes, or one registered through DCR. A
  document that describes no client is refused with why.
  """
  @spec find_by_client_id(String.t()) ::
          {:ok, McpOAuthClient.t()} | {:error, :not_found | String.t()}
  def find_by_client_id(client_id) when is_binary(client_id) do
    case Computers.client() do
      %McpOAuthClient{client_id: ^client_id} = client ->
        {:ok, client}

      _ ->
        if ClientDocument.document?(client_id),
          do: ClientDocument.fetch(client_id),
          else: find_registered(client_id)
    end
  end

  defp find_registered(client_id) do
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
  Check if a redirect_uri is valid for a client: one it lists, or on any port
  for a loopback URI it lists without one (RFC 8252), as a native client
  listens on whichever port it gets.
  """
  @spec valid_redirect_uri?(McpOAuthClient.t(), String.t()) :: boolean()
  def valid_redirect_uri?(%McpOAuthClient{redirect_uris: uris}, redirect_uri) do
    redirect_uri in uris or Enum.any?(uris, &any_port?(&1, redirect_uri))
  end

  defp any_port?(listed, redirect_uri) do
    Regex.match?(~r{^http://(localhost|127\.0\.0\.1|\[::1\])/}, listed) and
      case URI.parse(redirect_uri) do
        %URI{scheme: "http"} = uri -> URI.to_string(%{uri | port: 80}) == listed
        _ -> false
      end
  end
end
