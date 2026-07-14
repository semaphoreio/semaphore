defmodule Guard.Store.CliAuthCode do
  @moduledoc """
  Store for sem-ai CLI sign-in authorization records (RFC 8628 device grant).

  Redemption is single-use and multi-pod safe: `lock_*` locks the row with
  SELECT FOR UPDATE inside a transaction and the caller marks it consumed, so
  concurrent `/cli/token` requests (even on different guard pods) cannot
  double-redeem. Device and user codes are compared by their sha256 hashes; the
  plaintext is never stored.
  """

  import Ecto.Query

  alias Guard.Repo
  alias Guard.Repo.CliAuthCode

  # ── generation / hashing ────────────────────────────────────────────────

  # Base-20 charset: no vowels (can't spell words) and no ambiguous glyphs
  # (0/O, 1/I/L). 8 chars => 20^8 ~= 2.56e10 (~34.8 bits) of entropy.
  @user_code_alphabet ~c"BCDFGHJKLMNPQRSTVWXZ"
  @user_code_length 8

  @doc "Secure random device_code (256-bit), returned to the CLI in plaintext."
  @spec generate_device_code() :: String.t()
  def generate_device_code,
    do: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

  @doc "Secure random 8-char base-20 user_code (no dashes), for display grouping."
  @spec generate_user_code() :: String.t()
  def generate_user_code do
    :crypto.strong_rand_bytes(@user_code_length)
    |> :binary.bin_to_list()
    |> Enum.map_join("", fn byte ->
      <<Enum.at(@user_code_alphabet, rem(byte, length(@user_code_alphabet)))>>
    end)
  end

  @doc "Display form of a user_code, grouped as XXXX-XXXX."
  @spec format_user_code(String.t()) :: String.t()
  def format_user_code(<<a::binary-size(4), b::binary-size(4)>>), do: "#{a}-#{b}"
  def format_user_code(code) when is_binary(code), do: code

  @doc "Normalize user input: strip non-alphanumerics and uppercase before compare."
  @spec normalize_user_code(String.t()) :: String.t()
  def normalize_user_code(code) when is_binary(code) do
    code
    |> String.replace(~r/[^A-Za-z0-9]/, "")
    |> String.upcase()
  end

  def normalize_user_code(_), do: ""

  @doc "sha256 hex hash used for device_code and user_code at rest."
  @spec hash(String.t()) :: String.t()
  def hash(value) when is_binary(value),
    do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  # ── create ──────────────────────────────────────────────────────────────

  @spec create(map()) :: {:ok, CliAuthCode.t()} | {:error, term()}
  def create(params) do
    %CliAuthCode{}
    |> CliAuthCode.changeset(params)
    |> Repo.insert()
  end

  # ── device (RFC 8628) ─────────────────────────────────────────────────────

  @doc """
  Lock the pending, unexpired device row for a normalized user_code. Must run
  inside a Repo.transaction: `Guard.CLIAuth.verify_user_code/2` folds the
  attempt-cap check and the attempt increment into this lock, so concurrent
  entries of the same code serialize and the cap is strict.
  """
  @spec lock_pending_by_user_code(String.t()) ::
          {:ok, CliAuthCode.t()} | {:error, :not_found}
  def lock_pending_by_user_code(normalized_user_code) when is_binary(normalized_user_code) do
    now = now()
    user_code_hash = hash(normalized_user_code)

    query =
      CliAuthCode
      |> where([ac], ac.flow_type == "device" and ac.user_code_hash == ^user_code_hash)
      |> where([ac], ac.status == "pending" and ac.expires_at > ^now)
      |> lock("FOR UPDATE")

    case Repo.one(query) do
      nil -> {:error, :not_found}
      auth_code -> {:ok, auth_code}
    end
  end

  @doc "Fetch a device row by id (used when rendering consent / recording a decision)."
  @spec get_device(binary()) :: {:ok, CliAuthCode.t()} | {:error, :not_found}
  def get_device(id) do
    case Repo.get_by(CliAuthCode, id: id, flow_type: "device") do
      nil -> {:error, :not_found}
      auth_code -> {:ok, auth_code}
    end
  end

  @doc """
  Lock a device row by its device_code hash regardless of status (the caller
  inspects status/expiry). Must run inside a Repo.transaction.
  """
  @spec lock_device_by_code_hash(String.t()) ::
          {:ok, CliAuthCode.t()} | {:error, :not_found}
  def lock_device_by_code_hash(device_code_hash) when is_binary(device_code_hash) do
    query =
      CliAuthCode
      |> where([ac], ac.flow_type == "device" and ac.device_code_hash == ^device_code_hash)
      |> lock("FOR UPDATE")

    case Repo.one(query) do
      nil -> {:error, :not_found}
      auth_code -> {:ok, auth_code}
    end
  end

  @doc "Lock a device row by id, asserting it is still pending and unexpired."
  @spec lock_pending_device(binary()) :: {:ok, CliAuthCode.t()} | {:error, :not_found}
  def lock_pending_device(id) do
    now = now()

    query =
      CliAuthCode
      |> where([ac], ac.id == ^id and ac.flow_type == "device")
      |> where([ac], ac.status == "pending" and ac.expires_at > ^now)
      |> lock("FOR UPDATE")

    case Repo.one(query) do
      nil -> {:error, :not_found}
      auth_code -> {:ok, auth_code}
    end
  end

  @doc "Increment attempt_count on a device row (user_code entry throttling)."
  @spec increment_attempt(CliAuthCode.t()) :: {:ok, CliAuthCode.t()} | {:error, term()}
  def increment_attempt(%CliAuthCode{} = row) do
    update_row(row, %{attempt_count: row.attempt_count + 1})
  end

  # ── status transitions ─────────────────────────────────────────────────────

  @doc "Approve a device row, recording who approved and the consented token action."
  @spec approve(CliAuthCode.t(), binary(), String.t()) ::
          {:ok, CliAuthCode.t()} | {:error, term()}
  def approve(%CliAuthCode{} = row, user_id, token_action),
    do: update_row(row, %{status: "approved", user_id: user_id, token_action: token_action})

  @spec deny(CliAuthCode.t()) :: {:ok, CliAuthCode.t()} | {:error, term()}
  def deny(%CliAuthCode{} = row), do: update_row(row, %{status: "denied"})

  @doc "Mark a locked, approved code consumed. Run in the same transaction as the lock."
  @spec mark_consumed(CliAuthCode.t()) :: {:ok, CliAuthCode.t()} | {:error, term()}
  def mark_consumed(%CliAuthCode{} = row), do: update_row(row, %{status: "consumed"})

  @spec update_row(CliAuthCode.t(), map()) :: {:ok, CliAuthCode.t()} | {:error, term()}
  def update_row(%CliAuthCode{} = row, attrs) do
    row
    |> CliAuthCode.changeset(attrs)
    |> Repo.update()
  end

  # ── housekeeping ────────────────────────────────────────────────────────────

  @doc "Delete expired codes (table-bloat guard; safe to run periodically)."
  @spec cleanup_expired() :: {integer(), nil}
  def cleanup_expired do
    CliAuthCode
    |> where([ac], ac.expires_at < ^now())
    |> Repo.delete_all()
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
