defmodule Guard.Store.CliAuthCode do
  @moduledoc """
  Store for sem-ai CLI loopback-login authorization codes.

  Single-use and multi-pod safe: redemption locks the row with SELECT FOR UPDATE
  inside a transaction and marks it used, so concurrent /cli/token requests (even
  on different guard pods) cannot double-redeem. Mirrors Guard.Store.McpOAuthAuthCode.
  """

  require Logger
  import Ecto.Query

  alias Guard.Repo
  alias Guard.Repo.CliAuthCode

  @doc """
  Lock a valid, unused, unexpired code with SELECT FOR UPDATE.
  Must be called inside a Repo.transaction.
  """
  @spec lock_code(String.t()) :: {:ok, CliAuthCode.t()} | {:error, :invalid_or_used}
  def lock_code(code) when is_binary(code) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      CliAuthCode
      |> where([ac], ac.code == ^code)
      |> where([ac], is_nil(ac.used_at) and ac.expires_at > ^now)
      |> lock("FOR UPDATE")

    case Repo.one(query) do
      nil -> {:error, :invalid_or_used}
      auth_code -> {:ok, auth_code}
    end
  end

  @doc "Mark a locked code as used. Must run in the same transaction as lock_code/1."
  @spec mark_code_used(CliAuthCode.t()) :: {:ok, CliAuthCode.t()} | {:error, Ecto.Changeset.t()}
  def mark_code_used(%CliAuthCode{} = auth_code) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    auth_code
    |> Ecto.Changeset.change(used_at: now)
    |> Repo.update()
  end

  @spec create(map()) :: {:ok, CliAuthCode.t()} | {:error, term()}
  def create(params) do
    %CliAuthCode{}
    |> CliAuthCode.changeset(params)
    |> Repo.insert()
  end

  @doc "Secure random, URL-safe authorization code."
  @spec generate_code() :: String.t()
  def generate_code, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

  @doc "Delete expired codes (table-bloat guard; safe to run periodically)."
  @spec cleanup_expired() :: {integer(), nil}
  def cleanup_expired do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    CliAuthCode
    |> where([ac], ac.expires_at < ^now)
    |> Repo.delete_all()
  end
end
