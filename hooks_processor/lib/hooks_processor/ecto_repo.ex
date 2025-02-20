defmodule HooksProcessor.EctoRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :hooks_processor,
    adapter: Ecto.Adapters.Postgres
end
