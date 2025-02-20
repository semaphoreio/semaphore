defmodule Notifications.Repo do
  use Ecto.Repo,
    otp_app: :notifications,
    adapter: Ecto.Adapters.Postgres

  use Paginator
end
