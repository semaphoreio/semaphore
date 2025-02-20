defmodule Zebra.LegacyRepo do
  use Ecto.Repo, otp_app: :zebra, adapter: Ecto.Adapters.Postgres
  use Paginator
end
