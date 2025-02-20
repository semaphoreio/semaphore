defmodule Scheduler.PeriodicsRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :scheduler,
    adapter: Ecto.Adapters.Postgres

  @spec scrivener_defaults() :: Keyword.t()
  def scrivener_defaults, do: [page_size: 30]

  @spec paginator_defaults() :: Keyword.t()
  def paginator_defaults, do: [limit: 30, maximum_limit: 100]

  @spec paginate_offset(Ecto.Query.t(), map | Keyword.t()) :: Scrivener.Page.t()
  def paginate_offset(pageable, options \\ []) do
    config = Scrivener.Config.new(__MODULE__, scrivener_defaults(), options)
    Scrivener.paginate(pageable, config)
  end

  @spec paginate_keyset(Ecto.Query.t(), Keyword.t(), Keyword.t()) :: Paginator.Page.t()
  def paginate_keyset(queryable, opts \\ [], repo_opts \\ []) do
    opts = Keyword.merge(paginator_defaults(), opts)
    Paginator.paginate(queryable, opts, __MODULE__, repo_opts)
  end
end
