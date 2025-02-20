defmodule Block.EctoRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :block,
    adapter: Ecto.Adapters.Postgres
end
