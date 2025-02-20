defmodule Gofer.EctoRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :gofer,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 30
end
