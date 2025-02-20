defmodule Audit.Repo do
  use Ecto.Repo, otp_app: :audit, adapter: Ecto.Adapters.Postgres

  use Paginator,
    # sets the default limit to 500
    limit: 500,
    maximum_limit: 5000
end
