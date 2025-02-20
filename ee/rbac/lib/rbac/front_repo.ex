defmodule Rbac.FrontRepo do
  use Ecto.Repo,
    otp_app: :rbac,
    adapter: Ecto.Adapters.Postgres
end
