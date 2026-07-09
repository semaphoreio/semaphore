defmodule Guard.Repo.Migrations.CreateCliAuthCodes do
  use Ecto.Migration

  @moduledoc """
  Single table backing both sem-ai CLI signup flows:

    * loopback + PKCE (RFC 8252) — `flow_type = "loopback"`
    * device authorization grant (RFC 8628) — `flow_type = "device"`

  Loopback rows carry `code`/`code_challenge`/`redirect_uri` and are born
  `approved` (the user is known at issue time). Device rows carry hashed
  `device_code`/`user_code` and start `pending` with a null `user_id` until the
  human approves them on the verification page.
  """

  def change do
    create table(:cli_auth_codes, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(:flow_type, :string, null: false)
      add(:status, :string, null: false, default: "pending")

      # loopback (RFC 8252)
      add(:code, :string)
      add(:code_challenge, :string)
      add(:redirect_uri, :text)

      # device (RFC 8628) — codes are stored hashed (sha256 hex) at rest
      add(:device_code_hash, :string)
      add(:user_code_hash, :string)

      # device consent context, captured at POST /cli/device
      add(:requester_ip, :string)
      add(:requester_geo, :string)
      add(:requester_user_agent, :text)

      # device polling
      add(:interval, :integer, null: false, default: 5)
      add(:last_polled_at, :utc_datetime)
      add(:attempt_count, :integer, null: false, default: 0)

      # shared: null until approved (device); set at issue (loopback)
      add(:user_id, references(:rbac_users, type: :uuid, on_delete: :delete_all))
      add(:expires_at, :utc_datetime, null: false)

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create(unique_index(:cli_auth_codes, [:code], where: "code IS NOT NULL"))

    create(
      unique_index(:cli_auth_codes, [:device_code_hash], where: "device_code_hash IS NOT NULL")
    )

    # Only one *pending* row may hold a given user_code; consumed/denied/expired
    # rows free the code so the tiny base-20 space is not exhausted over time.
    create(
      unique_index(:cli_auth_codes, [:user_code_hash],
        where: "user_code_hash IS NOT NULL AND status = 'pending'",
        name: :cli_auth_codes_pending_user_code_index
      )
    )

    create(index(:cli_auth_codes, [:user_id]))
    create(index(:cli_auth_codes, [:expires_at]))
  end
end
