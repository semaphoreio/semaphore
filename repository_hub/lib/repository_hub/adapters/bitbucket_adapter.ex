defmodule RepositoryHub.BitbucketAdapter do
  @moduledoc """

  Notes:
    - Bitbucket uses URL's as page tokens. Currently those tokens are base64 encoded, and sent
  """
  alias RepositoryHub.{
    UniversalAdapter,
    UserClient,
    Toolkit,
    BitbucketAdapter
  }

  import Toolkit

  @type t :: %RepositoryHub.BitbucketAdapter{}

  defstruct [:integration_type, :name, :short_name]

  @doc """
  Creates a new BitbucketAdapter

  # Examples

    iex> RepositoryHub.BitbucketAdapter.new("bitbucket")
    %RepositoryHub.BitbucketAdapter{integration_type: "bitbucket", name: "Bitbucket", short_name: "bbo"}

    iex> RepositoryHub.BitbucketAdapter.new("BITBUCKET")
    %RepositoryHub.BitbucketAdapter{integration_type: "bitbucket", name: "Bitbucket", short_name: "bbo"}
  """
  @spec new(integration_type :: String.t()) :: BitbucketAdapter.t()
  def new(integration_type) do
    %BitbucketAdapter{
      integration_type: String.downcase(integration_type),
      name: "Bitbucket",
      short_name: "bbo"
    }
  end

  def integration_types, do: ["bitbucket"]

  @doc """
  Fetches page token from paged result response from bitbucket and Base64 encodes it

  # Examples

    iex> RepositoryHub.BitbucketAdapter.next_page_token(%{})
    ""

    iex> RepositoryHub.BitbucketAdapter.next_page_token(nil)
    ""

    iex> RepositoryHub.BitbucketAdapter.next_page_token(%{"next" => "some_token"})
    "c29tZV90b2tlbg=="

  """
  @spec next_page_token(any()) :: String.t()
  def next_page_token(paged_result) do
    paged_result
    |> case do
      %{"next" => next_page_url} ->
        Base.encode64(next_page_url)

      _ ->
        ""
    end
  end

  def multi(_adapter, repository_id, stream \\ nil) do
    alias Ecto.Multi

    with {:ok, context} <- UniversalAdapter.context(repository_id, stream) do
      Enum.reduce(context, Multi.new(), fn {key, value}, multi ->
        multi
        |> Multi.put(key, value)
      end)
      |> Multi.run(:bitbucket_token, fn _repo, context ->
        fetch_token(context.project.metadata.owner_id)
      end)
    end
  end

  def fetch_token(user_id) do
    [integration_type] = integration_types()

    integration_type
    |> UserClient.get_repository_token(user_id)
  end

  def context(_adapter, repository_id, stream \\ nil) do
    with {:ok, context} <- UniversalAdapter.context(repository_id, stream),
         {:ok, bitbucket_token} <- BitbucketAdapter.fetch_token(context.project.metadata.owner_id) do
      context
      |> Map.put(:bitbucket_token, bitbucket_token)
      |> wrap()
    end
  end
end
