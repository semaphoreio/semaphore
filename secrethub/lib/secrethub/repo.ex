defmodule Secrethub.Repo do
  use Ecto.Repo, otp_app: :secrethub, adapter: Ecto.Adapters.Postgres

  use Paginator,
    limit: 100,
    maximum_limit: 100
end
