defmodule Guard.Store.McpOAuthConsentChallenge do
  @moduledoc """
  Store module for MCP OAuth consent challenge operations.
  """

  import Ecto.Query

  alias Guard.Repo
  alias Guard.Repo.McpOAuthConsentChallenge

  @spec create(map()) :: {:ok, McpOAuthConsentChallenge.t()} | {:error, term()}
  def create(params) do
    %McpOAuthConsentChallenge{}
    |> McpOAuthConsentChallenge.changeset(params)
    |> Repo.insert()
  end

  @spec get_active(String.t(), String.t()) ::
          {:ok, McpOAuthConsentChallenge.t()} | {:error, :not_found}
  def get_active(challenge_id, user_id) when is_binary(challenge_id) and is_binary(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(c in McpOAuthConsentChallenge,
      where:
        c.id == ^challenge_id and c.user_id == ^user_id and is_nil(c.consumed_at) and
          c.expires_at > ^now
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      challenge -> {:ok, challenge}
    end
  end

  @spec consume(String.t(), String.t()) ::
          {:ok, McpOAuthConsentChallenge.t()} | {:error, :invalid_or_used}
  def consume(challenge_id, user_id) when is_binary(challenge_id) and is_binary(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      from(c in McpOAuthConsentChallenge,
        where:
          c.id == ^challenge_id and c.user_id == ^user_id and is_nil(c.consumed_at) and
            c.expires_at > ^now,
        select: c
      )

    case Repo.update_all(query, set: [consumed_at: now]) do
      {1, [challenge]} -> {:ok, challenge}
      {0, _} -> {:error, :invalid_or_used}
    end
  end
end
