defmodule BranchHub.Repo do
  use Ecto.Repo,
    otp_app: :branch_hub,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 30
end
