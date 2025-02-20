defmodule Scheduler.FrontRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :scheduler,
    adapter: Ecto.Adapters.Postgres
end
