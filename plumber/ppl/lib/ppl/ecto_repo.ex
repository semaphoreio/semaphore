defmodule Ppl.EctoRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :ppl,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 30

  def paginate_keyset(queryable, opts \\ [], repo_opts \\ []) do
    defaults = [limit: 30]
    opts = Keyword.merge(defaults, opts)
    Paginator.paginate(queryable, opts, __MODULE__, repo_opts)
  end
end
