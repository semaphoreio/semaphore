defmodule Front.Models.Billing do
  require Logger

  alias Front.Models.{
    Billing.Budget,
    Billing.Cost,
    Billing.Credits,
    Billing.Invoice,
    Billing.Project,
    Billing.ProjectCost,
    Billing.Seat,
    Billing.Spending
  }

  @type billing_opts :: [
          reload_cache?: boolean(),
          cache_ttl: pos_integer()
        ]

  @spec current_spending(String.t(), billing_opts()) :: Spending.t()
  def current_spending(organization_id, opts \\ []) do
    opts = parse_opts(opts, cache_ttl: :timer.hours(1))

    {:ok, response} = Front.Clients.Billing.current_spending(%{org_id: organization_id}, opts)

    response.spending
    |> Spending.from_grpc()
  end

  @spec find_spending(String.t()) :: Spending.t()
  def find_spending(spending_id, opts \\ []) do
    opts = parse_opts(opts, cache_ttl: :timer.hours(1))

    {:ok, response} =
      Front.Clients.Billing.describe_spending(
        %{
          spending_id: spending_id
        },
        opts
      )

    response.spending
    |> Spending.from_grpc()
  end

  @spec list_spendings(String.t()) :: [Spending.t()]
  def list_spendings(organization_id, opts \\ []) do
    opts = parse_opts(opts, cache_ttl: :timer.hours(1))

    {:ok, response} =
      Front.Clients.Billing.list_spendings(
        %{
          org_id: organization_id
        },
        opts
      )

    response.spendings
    |> Enum.map(&Spending.from_grpc/1)
  end

  @spec spending_report(String.t()) :: [Cost.t()]
  def spending_report(spending_id, opts \\ []) do
    opts = parse_opts(opts, cache_ttl: :timer.hours(1))

    {:ok, response} =
      Front.Clients.Billing.list_daily_costs(
        %{
          spending_id: spending_id
        },
        opts
      )

    response.costs
    |> Enum.map(&Cost.from_grpc/1)
  end

  @spec list_seats(String.t()) :: [Seat.t()]
  def list_seats(spending_id, opts \\ []) do
    opts = parse_opts(opts, cache_ttl: :timer.hours(12))

    {:ok, response} =
      Front.Clients.Billing.list_spending_seats(
        %{
          spending_id: spending_id
        },
        opts
      )

    response.seats
    |> Enum.map(&Seat.from_grpc/1)
  end

  @spec list_invoices(String.t()) :: [Invoice.t()]
  def list_invoices(org_id, opts \\ []) do
    opts = parse_opts(opts, cache_ttl: :timer.hours(24))

    {:ok, response} =
      Front.Clients.Billing.list_invoices(
        %{
          org_id: org_id
        },
        opts
      )

    response.invoices
    |> Enum.map(&Invoice.from_grpc/1)
  end

  @spec list_projects(String.t(), DateTime.t(), DateTime.t()) :: [Project.t()]
  def list_projects(org_id, from_date, to_date, opts \\ []) do
    opts = parse_opts(opts, cache_ttl: :timer.hours(12))

    from_date =
      from_date
      |> DateTime.to_unix()
      |> then(&%{seconds: &1})

    to_date =
      to_date
      |> DateTime.to_unix()
      |> then(&%{seconds: &1})

    {:ok, response} =
      Front.Clients.Billing.list_projects(
        %{
          org_id: org_id,
          from_date: from_date,
          to_date: to_date
        },
        opts
      )

    response.projects
    |> Enum.map(&Project.from_grpc/1)
  end

  @spec describe_project(String.t(), DateTime.t(), DateTime.t(), Keyword.t()) :: %{
          project: Project.t(),
          costs: [ProjectCost.t()]
        }
  def describe_project(project_id, from_date, to_date, opts \\ []) do
    opts = parse_opts(opts, cache_ttl: :timer.hours(12))

    from_date =
      from_date
      |> DateTime.to_unix()
      |> then(&%{seconds: &1})

    to_date =
      to_date
      |> DateTime.to_unix()
      |> then(&%{seconds: &1})

    {:ok, response} =
      Front.Clients.Billing.describe_project(
        %{
          project_id: project_id,
          from_date: from_date,
          to_date: to_date
        },
        opts
      )

    project = Project.from_grpc(response.project)
    costs = response.costs |> Enum.map(&ProjectCost.from_grpc/1)

    %{project: project, costs: costs}
  end

  @spec get_budget(String.t()) :: Budget.t()
  def get_budget(organization_id, opts \\ []) do
    opts = parse_opts(opts, use_cache?: false)

    {:ok, response} =
      Front.Clients.Billing.get_budget(
        %{
          org_id: organization_id
        },
        opts
      )

    response.budget
    |> Budget.from_grpc()
  end

  @spec update_budget(String.t(), limit :: String.t(), email :: String.t(), Keyword.t()) ::
          Budget.t()
  def update_budget(organization_id, limit, email, opts \\ []) do
    opts = parse_opts(opts, use_cache?: false)

    {:ok, response} =
      Front.Clients.Billing.set_budget(
        %{
          org_id: organization_id,
          budget: [limit: limit, email: email]
        },
        opts
      )

    response.budget
    |> Budget.from_grpc()
  end

  def get_credits(organization_id, opts \\ []) do
    opts = parse_opts(opts, cache_ttl: :timer.hours(24))

    {:ok, response} =
      Front.Clients.Billing.credits_usage(
        %{
          org_id: organization_id
        },
        opts
      )

    response
    |> Credits.from_grpc()
  end

  def upgrade_plan(organization_id, plan_slug, opts \\ []) do
    opts = parse_opts(opts, use_cache?: false)

    {:ok, response} =
      Front.Clients.Billing.upgrade_plan(
        %{
          org_id: organization_id,
          plan_slug: plan_slug
        },
        opts
      )

    %{
      errors: response.errors,
      spending_id: response.spending_id,
      payment_method_url: response.payment_method_url
    }
  rescue
    e ->
      Logger.error("Error upgrading plan: #{inspect(e)}")

      %{
        errors: ["Upgrading plan failed."],
        spending_id: "",
        payment_method_url: ""
      }
  end

  @spec parse_opts(billing_opts(), overrides :: Keyword.t()) :: Keyword.t()
  defp parse_opts(opts, overrides) do
    opts
    |> Keyword.merge(overrides)
  end
end
