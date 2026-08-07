defmodule Guard.Repo.Migrations.AddTokenActionToCliAuthCodes do
  use Ecto.Migration

  @moduledoc """
  What the human consented to on the device consent screen, recorded at
  approval time: "mint" (fresh account, no token yet) or "rotate" (account
  already had a token and the user explicitly agreed to reset it). The poll
  that redeems the device_code executes exactly the consented action.
  """

  def change do
    alter table(:cli_auth_codes) do
      add(:token_action, :string)
    end
  end
end
