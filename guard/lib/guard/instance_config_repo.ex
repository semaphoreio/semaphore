defmodule Guard.InstanceConfigRepo do
  use Ecto.Repo,
    otp_app: :guard,
    adapter: Ecto.Adapters.Postgres
end
