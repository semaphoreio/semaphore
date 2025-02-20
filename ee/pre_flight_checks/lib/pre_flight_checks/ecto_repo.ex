defmodule PreFlightChecks.EctoRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :pre_flight_checks,
    adapter: Ecto.Adapters.Postgres
end
