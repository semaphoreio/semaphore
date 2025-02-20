defmodule Projecthub.Repo do
  use Ecto.Repo,
    otp_app: :projecthub,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 50

  def cursor_paginate(queryable, opts \\ [], repo_opts \\ []) do
    defaults = [limit: 50]

    opts = Keyword.merge(defaults, opts)
    Paginator.paginate(queryable, [{:maximum_limit, 100} | opts], __MODULE__, repo_opts)
  end
end
