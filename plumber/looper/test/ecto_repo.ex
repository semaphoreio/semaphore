defmodule Looper.Test.EctoRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :looper,
    adapter: Ecto.Adapters.Postgres
end
