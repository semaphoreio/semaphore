defmodule Support.Stubs.Billing do
  alias Support.Stubs
  alias Support.Stubs.DB

  defmodule RandomSum do
    def generate(n, total) when n > 1 do
      rand_num = :rand.uniform() * total
      [rand_num | generate(n - 1, total - rand_num)]
    end

    def generate(1, total), do: [total]
  end

  alias InternalApi.Billing.{
    AcknowledgeTrialEndResponse,
    Budget,
    CanSetupOrganizationResponse,
    CanUpgradePlanResponse,
    ChargingType,
    CreditAvailable,
    CreditBalance,
    CreditBalanceType,
    CreditsUsageRequest,
    CreditsUsageResponse,
    CreditType,
    CurrentSpendingRequest,
    CurrentSpendingResponse,
    DescribeProjectRequest,
    DescribeProjectResponse,
    DescribeSpendingRequest,
    DescribeSpendingResponse,
    GetBudgetRequest,
    GetBudgetResponse,
    Invoice,
    ListDailyCostsRequest,
    ListDailyCostsResponse,
    ListInvoicesRequest,
    ListInvoicesResponse,
    ListProjectsRequest,
    ListProjectsResponse,
    ListSpendingSeatsRequest,
    ListSpendingSeatsResponse,
    ListSpendingsRequest,
    ListSpendingsResponse,
    PlanSummary,
    SetBudgetResponse,
    SetupOrganizationResponse,
    Spending,
    SpendingGroup,
    SpendingItem,
    SpendingSummary,
    SpendingType,
    UpgradePlanRequest,
    UpgradePlanResponse
  }

  alias InternalApi.Usage.{
    Seat,
    SeatOrigin,
    SeatStatus
  }

  def init do
    DB.add_table(:billing, [:request, :response])

    __MODULE__.Grpc.init()
  end

  def set_org_defaults(org_id) do
    current_month = Timex.now() |> Timex.beginning_of_month()

    from_date = current_month
    to_date = current_month |> Timex.end_of_month()
    formatted_from = Timex.format!(current_month, "{0D} {Mshort}")
    formated_to = Timex.format!(to_date, "{0D} {Mshort}, {YYYY}")

    spendings = [
      stub_spending(
        plan_summary: stub_plan(:startup_hybrid),
        display_name: "Startup - Hybrid #{formatted_from} - #{formated_to}",
        from_date: [seconds: from_date |> Timex.to_unix()],
        to_date: [seconds: to_date |> Timex.to_unix()],
        summary:
          stub_spending_summary(
            total_bill: "$15.00",
            subscription_total: "$13.50",
            usage_total: "$7.74",
            usage_used: "$0.00",
            credits_total: "$7.51",
            credits_used: "$7.49",
            credits_starting: "$15.00",
            discount: "10",
            discount_amount: "$2.249"
          )
      ),
      stub_spending(
        plan_summary: stub_plan(:prepaid),
        display_name: "Prepaid 01 Dec - 31 Dec, 2022",
        from_date: [seconds: ~D[2022-12-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-12-31] |> Timex.to_datetime() |> Timex.to_unix()],
        summary:
          stub_spending_summary(
            total_bill: "$15.00",
            subscription_total: "$15.00",
            usage_total: "$7.49",
            usage_used: "$0.00",
            credits_total: "$7.51",
            credits_used: "$7.49",
            credits_starting: "$15.00"
          )
      ),
      stub_spending(
        plan_summary: stub_plan(:postpaid),
        display_name: "Postpaid 01 Dec - 31 Dec, 2022",
        from_date: [seconds: ~D[2022-12-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-12-31] |> Timex.to_datetime() |> Timex.to_unix()],
        summary:
          stub_spending_summary(
            total_bill: "$15.00",
            subscription_total: "$15.00",
            usage_total: "$7.49",
            usage_used: "$0.00",
            credits_total: "$7.51",
            credits_used: "$7.49",
            credits_starting: "$15.00"
          )
      ),
      stub_spending(
        plan_summary: stub_plan(:postpaid, details: []),
        display_name: "[Postpaid-no-details] 01 Dec - 31 Dec, 2022",
        from_date: [seconds: ~D[2022-12-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-12-31] |> Timex.to_datetime() |> Timex.to_unix()],
        summary:
          stub_spending_summary(
            total_bill: "$15.00",
            subscription_total: "$15.00",
            usage_total: "$7.49",
            usage_used: "$0.00",
            credits_total: "$7.51",
            credits_used: "$7.49",
            credits_starting: "$15.00"
          )
      ),
      stub_spending(
        plan_summary:
          stub_plan(:postpaid,
            flags: [:SUBSCRIPTION_FLAG_TRIAL],
            subscription_ends_on: [
              seconds:
                Timex.now() |> Timex.shift(days: 5) |> Timex.to_datetime() |> Timex.to_unix()
            ]
          ),
        display_name: "[Postpaid-trial] 01 Dec - 31 Dec, 2022",
        from_date: [seconds: ~D[2022-12-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-12-31] |> Timex.to_datetime() |> Timex.to_unix()],
        summary:
          stub_spending_summary(
            total_bill: "$15.00",
            subscription_total: "$15.00",
            usage_total: "$7.49",
            usage_used: "$0.00",
            credits_total: "$7.51",
            credits_used: "$7.49",
            credits_starting: "$15.00"
          )
      ),
      stub_spending(
        plan_summary:
          stub_plan(:postpaid,
            flags: [:SUBSCRIPTION_FLAG_ELIGIBLE_FOR_ADDONS]
          ),
        display_name: "[Postpaid-with-discount] 01 Dec - 31 Dec, 2022",
        from_date: [seconds: ~D[2022-12-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-12-31] |> Timex.to_datetime() |> Timex.to_unix()],
        summary:
          stub_spending_summary(
            total_bill: "$11.24",
            subscription_total: "$7.50",
            usage_total: "$3.74",
            usage_used: "$0.00",
            credits_total: "$7.51",
            credits_used: "$7.49",
            credits_starting: "$15.00",
            discount: "50",
            discount_amount: "$11.24"
          ),
        groups: [
          Stubs.Billing.SpendingGroup.machine_time(),
          Stubs.Billing.SpendingGroup.seats(),
          Stubs.Billing.SpendingGroup.storage(),
          Stubs.Billing.SpendingGroup.addons(items: [], total_price: "$ 0.00")
        ]
      ),
      stub_spending(
        plan_summary:
          stub_plan(:postpaid,
            flags: [:SUBSCRIPTION_FLAG_ELIGIBLE_FOR_ADDONS]
          ),
        display_name: "[Postpaid-eligible-for-addons] 01 Dec - 31 Dec, 2022",
        from_date: [seconds: ~D[2022-12-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-12-31] |> Timex.to_datetime() |> Timex.to_unix()],
        summary:
          stub_spending_summary(
            total_bill: "$15.00",
            subscription_total: "$15.00",
            usage_total: "$7.49",
            usage_used: "$0.00",
            credits_total: "$7.51",
            credits_used: "$7.49",
            credits_starting: "$15.00"
          ),
        groups: [
          Stubs.Billing.SpendingGroup.machine_time(),
          Stubs.Billing.SpendingGroup.seats(),
          Stubs.Billing.SpendingGroup.storage(),
          Stubs.Billing.SpendingGroup.addons(items: [], total_price: "$ 0.00")
        ]
      ),
      stub_spending(
        plan_summary: stub_plan(:postpaid),
        display_name: "[Postpaid-not-eligible-for-addons] 01 Dec - 31 Dec, 2022",
        from_date: [seconds: ~D[2022-12-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-12-31] |> Timex.to_datetime() |> Timex.to_unix()],
        summary:
          stub_spending_summary(
            total_bill: "$15.00",
            subscription_total: "$15.00",
            usage_total: "$7.49",
            usage_used: "$0.00",
            credits_total: "$7.51",
            credits_used: "$7.49",
            credits_starting: "$15.00"
          ),
        groups: [
          Stubs.Billing.SpendingGroup.machine_time(),
          Stubs.Billing.SpendingGroup.seats(),
          Stubs.Billing.SpendingGroup.storage(),
          Stubs.Billing.SpendingGroup.addons(items: [])
        ]
      ),
      stub_spending(
        plan_summary:
          stub_plan(:postpaid,
            flags: [:SUBSCRIPTION_FLAG_TRIAL],
            subscription_ends_on: [
              seconds:
                Timex.now() |> Timex.shift(days: -1) |> Timex.to_datetime() |> Timex.to_unix()
            ]
          ),
        display_name: "[Postpaid-trial-expired] 01 Dec - 31 Dec, 2022",
        from_date: [seconds: ~D[2022-12-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-12-31] |> Timex.to_datetime() |> Timex.to_unix()],
        summary:
          stub_spending_summary(
            total_bill: "$15.00",
            subscription_total: "$15.00",
            usage_total: "$7.49",
            usage_used: "$0.00",
            credits_total: "$7.51",
            credits_used: "$7.49",
            credits_starting: "$15.00"
          )
      ),
      stub_spending(
        plan_summary:
          stub_plan(:postpaid, suspensions: [:SUBSCRIPTION_SUSPENSION_NO_PAYMENT_METHOD]),
        display_name: "[Postpaid-no-payment-method] 01 Dec - 31 Dec, 2022",
        from_date: [seconds: ~D[2022-12-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-12-31] |> Timex.to_datetime() |> Timex.to_unix()],
        summary:
          stub_spending_summary(
            total_bill: "$15.00",
            subscription_total: "$15.00",
            usage_total: "$7.49",
            usage_used: "$0.00",
            credits_total: "$7.51",
            credits_used: "$7.49",
            credits_starting: "$15.00"
          )
      ),
      stub_spending(
        plan_summary:
          stub_plan(:postpaid, suspensions: [:SUBSCRIPTION_SUSPENSION_PAYMENT_FAILED]),
        display_name: "[Postpaid-payment-failed] 01 Dec - 31 Dec, 2022",
        from_date: [seconds: ~D[2022-12-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-12-31] |> Timex.to_datetime() |> Timex.to_unix()],
        summary:
          stub_spending_summary(
            total_bill: "$15.00",
            subscription_total: "$15.00",
            usage_total: "$7.49",
            usage_used: "$0.00",
            credits_total: "$7.51",
            credits_used: "$7.49",
            credits_starting: "$15.00"
          )
      ),
      %{id: spending_without_seats_id} =
        stub_spending(
          plan_summary: stub_plan(:postpaid),
          display_name: "[Postpaid-no-seats] 01 Dec - 31 Dec, 2022",
          from_date: [seconds: ~D[2022-12-01] |> Timex.to_datetime() |> Timex.to_unix()],
          to_date: [seconds: ~D[2022-12-31] |> Timex.to_datetime() |> Timex.to_unix()],
          summary:
            stub_spending_summary(
              total_bill: "$15.00",
              subscription_total: "$15.00",
              usage_total: "$7.49",
              usage_used: "$0.00",
              credits_total: "$7.51",
              credits_used: "$7.49",
              credits_starting: "$15.00"
            )
        ),
      stub_spending(
        plan_summary: stub_plan(:prepaid),
        display_name: "Prepaid 01 Nov - 30 Nov, 2022",
        from_date: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-11-30] |> Timex.to_datetime() |> Timex.to_unix()],
        summary: stub_spending_summary()
      ),
      stub_spending(
        plan_summary: stub_plan(:grandfathered),
        display_name: "[Grandfathered] 01 Oct - 31 Oct, 2022",
        from_date: [seconds: ~D[2022-10-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-10-31] |> Timex.to_datetime() |> Timex.to_unix()],
        groups: [Stubs.Billing.SpendingGroup.machine_capacity()]
      ),
      stub_spending(
        plan_summary: stub_plan(:flat),
        display_name: "[Flat] 01 Sep - 30 Sep, 2022",
        from_date: [seconds: ~D[2022-09-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-09-30] |> Timex.to_datetime() |> Timex.to_unix()],
        groups: [Stubs.Billing.SpendingGroup.machine_capacity()]
      ),
      stub_spending(
        plan_summary: stub_plan(:classic_flat_4),
        display_name: "[Classic Flat] 01 Sep - 30 Sep, 2022",
        from_date: [seconds: ~D[2022-09-01] |> Timex.to_datetime() |> Timex.to_unix()],
        to_date: [seconds: ~D[2022-09-30] |> Timex.to_datetime() |> Timex.to_unix()],
        groups: [
          Stubs.Billing.SpendingGroup.machine_capacity(),
          Stubs.Billing.SpendingGroup.storage()
        ]
      )
    ]

    [current_spending | _] = spendings

    stubbed_results = []

    stubbed_results =
      stubbed_results ++
        [
          {CreditsUsageRequest.new(org_id: org_id),
           CreditsUsageResponse.new(
             credits_available: stub_credits_available(),
             credits_balance: stub_credits_balance()
           )}
        ]

    stubbed_results =
      stubbed_results ++
        [
          {ListSpendingsRequest.new(org_id: org_id),
           ListSpendingsResponse.new(spendings: spendings)}
        ]

    projects = [
      Stubs.Billing.Project.project(
        name: "billing",
        cost:
          Stubs.Billing.Project.project_cost(
            workflow_count: 123,
            total_price: "$ 123.45",
            spending_groups: [
              Stubs.Billing.SpendingGroup.machine_time(),
              Stubs.Billing.SpendingGroup.storage()
            ]
          )
      ),
      Stubs.Billing.Project.project(name: "zebra"),
      Stubs.Billing.Project.project(name: "front"),
      Stubs.Billing.Project.project(name: "launchpad2")
    ]

    stubbed_results =
      stubbed_results ++
        for spending <- spendings, into: [] do
          request =
            ListProjectsRequest.new(
              org_id: org_id,
              from_date: spending.from_date,
              to_date: spending.to_date
            )

          response = ListProjectsResponse.new(projects: projects)

          {request, response}
        end

    stubbed_results =
      stubbed_results ++
        for project <- projects, spending <- spendings, into: [] do
          request =
            DescribeProjectRequest.new(
              project_id: project.id,
              from_date: spending.from_date,
              to_date: spending.to_date
            )

          {project, costs} =
            Stubs.Billing.Project.project_with_costs(
              project,
              from_date: Timex.from_unix(spending.from_date.seconds),
              to_date: Timex.from_unix(spending.to_date.seconds)
            )

          response = DescribeProjectResponse.new(project: project, costs: costs)

          {request, response}
        end

    stubbed_results =
      stubbed_results ++
        for spending <- spendings, into: [] do
          seats_response =
            spending.id
            |> case do
              ^spending_without_seats_id ->
                ListSpendingSeatsResponse.new(seats: [])

              _ ->
                ListSpendingSeatsResponse.new(
                  seats: [
                    stub_seat(display_name: "Alice"),
                    stub_seat(
                      display_name: "Bob",
                      status: :SEAT_TYPE_NON_ACTIVE_MEMBER
                    ),
                    stub_seat(display_name: "alice 2"),
                    stub_seat(
                      display_name: "Charlie",
                      origin: :SEAT_ORIGIN_GITHUB,
                      status: :SEAT_TYPE_NON_MEMBER
                    ),
                    stub_seat(
                      display_name: "bob 2",
                      status: :SEAT_TYPE_NON_ACTIVE_MEMBER
                    ),
                    stub_seat(
                      display_name: "Dan",
                      origin: :SEAT_ORIGIN_BITBUCKET,
                      status: :SEAT_TYPE_NON_MEMBER
                    )
                  ]
                )
            end

          {ListSpendingSeatsRequest.new(org_id: org_id, spending_id: spending.id), seats_response}
        end

    stubbed_results =
      stubbed_results ++
        for spending <- spendings, into: [] do
          {DescribeSpendingRequest.new(spending_id: spending.id),
           DescribeSpendingResponse.new(spending: spending)}
        end

    stubbed_results =
      stubbed_results ++
        [
          {ListInvoicesRequest.new(org_id: org_id),
           ListInvoicesResponse.new(invoices: default_invoices())}
        ]

    stubbed_results =
      stubbed_results ++
        for spending <- spendings, into: [] do
          {ListDailyCostsRequest.new(spending_id: spending.id),
           ListDailyCostsResponse.new(costs: default_costs(spending))}
        end

    stubbed_results =
      stubbed_results ++
        [
          {GetBudgetRequest.new(org_id: org_id),
           GetBudgetResponse.new(budget: Budget.new(email: "", limit: "$ 0.00"))}
        ]

    stubbed_results =
      stubbed_results ++
        [
          {CurrentSpendingRequest.new(org_id: org_id),
           CurrentSpendingResponse.new(spending: current_spending)}
        ]

    stubbed_results =
      stubbed_results ++
        [
          {UpgradePlanRequest.new(org_id: org_id), UpgradePlanResponse.new(errors: [])}
        ]

    for {request, response} <- stubbed_results do
      stub(request, response)
    end
  end

  def default_costs(spending) do
    spending.groups
    |> Enum.flat_map(fn group ->
      {costs, _} =
        Timex.Interval.new(
          from: Timex.from_unix(spending.from_date.seconds),
          until: Timex.from_unix(spending.to_date.seconds),
          right_open: false
        )
        |> Enum.reduce({[], Decimal.new(0)}, fn day, {costs, rolling_cost} ->
          rand = random_float(0, 100)
          daily_cost = Decimal.from_float(rand)
          rolling_cost = Decimal.add(rolling_cost, daily_cost)

          price_for_the_day = "$ #{Decimal.round(daily_cost, 2)}"
          price_up_to_the_day = "$ #{Decimal.round(rolling_cost, 2)}"

          group_items =
            group.items
            |> Enum.group_by(& &1.name)
            |> Enum.flat_map(fn
              {_name, items} when length(items) > 1 ->
                items
                |> Enum.filter(&(&1.unit_price == ""))

              {_name, items} ->
                items
            end)

          items =
            if length(group_items) > 0 do
              rand_prices = RandomSum.generate(length(group_items), rand)

              Enum.zip(group_items, rand_prices)
              |> Enum.map(fn {item, price} ->
                price = "$ #{Decimal.round(Decimal.from_float(price), 2)}"
                %{item | total_price: price}
              end)
            else
              []
            end

          daily_cost =
            InternalApi.Billing.DailyCost.new(
              type: group.type,
              price_for_the_day: price_for_the_day,
              price_up_to_the_day: price_up_to_the_day,
              day: Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(day)),
              prediction: false,
              items: items
            )

          costs = [daily_cost | costs]
          {costs, rolling_cost}
        end)

      costs
      |> Enum.reverse()
    end)
  end

  def default_seats_group do
    seats =
      [
        {"Free", "5 max", "$ 0.00", 5, "$ 0.00"},
        {"Paid", "", "$ 5.00", 23, "$ 115.00"}
      ]
      |> Enum.map(fn {name, description, unit_price, units, total_price} ->
        SpendingItem.new(
          name: "seats",
          display_name: name,
          display_description: description,
          unit_price: unit_price,
          units: units,
          total_price: total_price
        )
      end)

    SpendingGroup.new(
      type: SpendingType.value(:SPENDING_TYPE_SEAT),
      items: seats,
      total_price: "$ 115.00"
    )
  end

  def default_invoices do
    [
      {"2022, 1 Nov - 30 Nov", "", "$23.59"},
      {"2022, 1 Oct - 31 Oct", "", "$15.00"},
      {"2022, 15 Sep - 30 Sep", "", "$0.00"},
      {"2022, 1 Sep - 15 Sep", "", "$0.00"}
    ]
    |> Enum.map(fn {name, url, total} ->
      Invoice.new(display_name: name, pdf_download_url: url, total_bill: total)
    end)
  end

  def stub_spending(params \\ []) do
    defaults = [
      id: Ecto.UUID.generate(),
      display_name: "Nov 1 - Nov 30",
      from_date: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      to_date: [seconds: ~D[2022-11-30] |> Timex.to_datetime() |> Timex.to_unix()],
      plan_summary: stub_plan(:prepaid),
      summary: stub_spending_summary(),
      groups: [
        Stubs.Billing.SpendingGroup.machine_time(),
        Stubs.Billing.SpendingGroup.seats(),
        Stubs.Billing.SpendingGroup.storage(),
        Stubs.Billing.SpendingGroup.addons()
      ]
    ]

    defaults
    |> Keyword.merge(params)
    |> Enum.map(fn
      {:from_date, value} ->
        {:from_date, Google.Protobuf.Timestamp.new(value)}

      {:to_date, value} ->
        {:to_date, Google.Protobuf.Timestamp.new(value)}

      other ->
        other
    end)
    |> Spending.new()
  end

  def stub_plan(type, params \\ [])

  def stub_plan(:startup_hybrid, params) do
    [
      id: Ecto.UUID.generate(),
      name: "Startup - Hybrid - Postpaid",
      slug: "startup_hybrid",
      details: [],
      charging_type: :CHARGING_TYPE_POSTPAID,
      subscription_starts_on: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      subscription_ends_on: nil
    ]
    |> merge_with_defaults(params)
    |> new_plan()
  end

  def stub_plan(:startup_hybrid_prepaid, params) do
    [
      id: Ecto.UUID.generate(),
      name: "Startup - Hybrid - Prepaid",
      slug: "startup_hybrid",
      details: [],
      charging_type: :CHARGING_TYPE_PREPAID,
      subscription_starts_on: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      subscription_ends_on: nil
    ]
    |> merge_with_defaults(params)
    |> new_plan()
  end

  def stub_plan(:free, params) do
    [
      id: Ecto.UUID.generate(),
      name: "Free",
      slug: "free",
      details: [],
      charging_type: :CHARGING_TYPE_NONE,
      subscription_starts_on: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      subscription_ends_on: nil
    ]
    |> merge_with_defaults(params)
    |> new_plan()
  end

  def stub_plan(:open_source, params) do
    [
      id: Ecto.UUID.generate(),
      name: "Open Source",
      slug: "open_source",
      details: [],
      charging_type: :CHARGING_TYPE_NONE,
      subscription_starts_on: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      subscription_ends_on: nil
    ]
    |> merge_with_defaults(params)
    |> new_plan()
  end

  def stub_plan(:scaleup_cloud, params) do
    [
      id: Ecto.UUID.generate(),
      name: "Scaleup - Cloud - Prepaid",
      slug: "scaleup",
      details: [],
      charging_type: :CHARGING_TYPE_PREPAID,
      subscription_starts_on: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      subscription_ends_on: nil
    ]
    |> merge_with_defaults(params)
    |> new_plan()
  end

  def stub_plan(:scaleup_hybrid, params) do
    [
      id: Ecto.UUID.generate(),
      name: "Scaleup - Hybrid - Prepaid",
      slug: "scaleup_hybrid",
      details: [],
      charging_type: :CHARGING_TYPE_PREPAID,
      subscription_starts_on: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      subscription_ends_on: nil
    ]
    |> merge_with_defaults(params)
    |> new_plan()
  end

  def stub_plan(:prepaid, params) do
    [
      id: Ecto.UUID.generate(),
      name: "Prepaid",
      slug: "prepaid",
      details: [],
      charging_type: :CHARGING_TYPE_PREPAID,
      subscription_starts_on: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      subscription_ends_on: nil
    ]
    |> merge_with_defaults(params)
    |> new_plan()
  end

  def stub_plan(:postpaid, params) do
    [
      id: Ecto.UUID.generate(),
      name: "Postpaid",
      slug: "postpaid",
      details: [
        %{
          display_name: "Cost per seat",
          display_value: "$ 5.00"
        },
        %{
          display_name: "Max job parallelism",
          display_value: "20"
        },
        %{
          display_name: "Max self-hosted agents",
          display_value: "unlimited"
        }
      ],
      charging_type: :CHARGING_TYPE_POSTPAID,
      subscription_starts_on: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      subscription_ends_on: nil
    ]
    |> merge_with_defaults(params)
    |> new_plan()
  end

  def stub_plan(:flat, params) do
    [
      id: Ecto.UUID.generate(),
      name: "Flat",
      slug: "flat",
      details: [],
      charging_type: :CHARGING_TYPE_FLATRATE,
      subscription_starts_on: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      subscription_ends_on: [seconds: ~D[2022-11-30] |> Timex.to_datetime() |> Timex.to_unix()]
    ]
    |> merge_with_defaults(params)
    |> new_plan()
  end

  def stub_plan(:grandfathered, params) do
    [
      id: Ecto.UUID.generate(),
      name: "Grandfathered",
      slug: "grandfathered",
      details: [],
      charging_type: :CHARGING_TYPE_GRANDFATHERED,
      subscription_starts_on: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      subscription_ends_on: [seconds: ~D[2022-11-30] |> Timex.to_datetime() |> Timex.to_unix()]
    ]
    |> merge_with_defaults(params)
    |> new_plan()
  end

  def stub_plan(:classic_flat_4, params) do
    [
      id: Ecto.UUID.generate(),
      name: "Classic Flat box 4",
      slug: "classic-box-4",
      details: [],
      charging_type: :CHARGING_TYPE_FLATRATE,
      subscription_starts_on: [seconds: ~D[2022-11-01] |> Timex.to_datetime() |> Timex.to_unix()],
      subscription_ends_on: [seconds: ~D[2022-11-30] |> Timex.to_datetime() |> Timex.to_unix()]
    ]
    |> merge_with_defaults(params)
    |> new_plan()
  end

  defp new_plan(params) do
    params
    |> Enum.map(fn
      {:details, value} ->
        {:details, Enum.map(value, &PlanSummary.Detail.new/1)}

      {:charging_type, value} ->
        {:charging_type, ChargingType.value(value)}

      {:subscription_starts_on, value} when value != nil ->
        {:subscription_starts_on, Google.Protobuf.Timestamp.new(value)}

      {:subscription_ends_on, value} when value != nil ->
        {:subscription_ends_on, Google.Protobuf.Timestamp.new(value)}

      {:flags, value} ->
        {:flags, Enum.map(value, &InternalApi.Billing.SubscriptionFlag.value/1)}

      {:suspensions, value} ->
        {:suspensions, Enum.map(value, &InternalApi.Billing.SubscriptionSuspension.value/1)}

      other ->
        other
    end)
    |> PlanSummary.new()
  end

  def stub_spending_summary(params \\ []) do
    defaults = [
      total_bill: "$ 387.20",
      subscription_total: "$ 15.00",
      usage_total: "$ 387.20",
      usage_used: "$ 372.20",
      credits_total: "$ 0.00",
      credits_used: "$ 15.00",
      credits_starting: "$ 15.00",
      discount: "0",
      discount_amount: "$ 0"
    ]

    defaults
    |> Keyword.merge(params)
    |> Enum.map(fn
      other ->
        other
    end)
    |> SpendingSummary.new()
  end

  def stub_seat(params \\ []) do
    defaults = [
      user_id: Ecto.UUID.generate(),
      display_name: "some name",
      origin: :SEAT_ORIGIN_SEMAPHORE,
      status: :SEAT_TYPE_ACTIVE_MEMBER,
      date: %{seconds: Timex.now() |> Timex.to_unix()}
    ]

    defaults
    |> Keyword.merge(params)
    |> Enum.map(fn
      {:origin, value} ->
        {:origin, SeatOrigin.value(value)}

      {:status, value} ->
        {:status, SeatStatus.value(value)}

      {:date, value} ->
        {:date, Google.Protobuf.Timestamp.new(value)}

      other ->
        other
    end)
    |> Seat.new()
  end

  defp stub_credits_available do
    types = [
      :CREDIT_TYPE_PREPAID,
      :CREDIT_TYPE_GIFT,
      :CREDIT_TYPE_SUBSCRIPTION,
      :CREDIT_TYPE_EDUCATIONAL
    ]

    given_at = %{seconds: Timex.now() |> Timex.to_unix()}
    expires_at = %{seconds: Timex.now() |> Timex.to_unix()}

    for type <- types, into: [] do
      remaining = random_float(0, 1000) |> Money.parse!()

      CreditAvailable.new(
        type: CreditType.value(type),
        amount: Money.to_string(remaining),
        given_at: Google.Protobuf.Timestamp.new(given_at),
        expires_at: Google.Protobuf.Timestamp.new(expires_at)
      )
    end
  end

  def stub_credits_balance do
    from = Timex.now() |> Timex.beginning_of_year()
    now = Timex.now() |> Timex.beginning_of_day()

    until =
      if from == now do
        now |> Timex.shift(days: 1)
      else
        now
      end

    [first_date | available_dates] =
      Timex.Interval.new(from: from, until: until)
      |> Enum.to_list()

    initial_balance =
      CreditBalance.new(
        type: CreditBalanceType.value(:CREDIT_BALANCE_TYPE_DEPOSIT),
        description: "Initial credits",
        amount: Money.new(10_000_000) |> Money.to_string(),
        occured_at: Google.Protobuf.Timestamp.new(%{seconds: Timex.to_unix(first_date)})
      )

    balance_history =
      for _i <- 0..10, into: [] do
        occured_at = available_dates |> Enum.random()

        type =
          [:CREDIT_BALANCE_TYPE_CHARGE, :CREDIT_BALANCE_TYPE_DEPOSIT]
          |> Enum.random()

        description =
          type
          |> case do
            :CREDIT_BALANCE_TYPE_CHARGE ->
              display_from =
                occured_at |> Timex.beginning_of_month() |> Timex.format!("%b %d", :strftime)

              display_to =
                occured_at |> Timex.end_of_month() |> Timex.format!("%b %d, %Y", :strftime)

              [
                "Credits expired",
                "Adjustment by semaphore team",
                "Usage from #{display_from} to #{display_to}"
              ]

            :CREDIT_BALANCE_TYPE_DEPOSIT ->
              [
                "Prepaid credits",
                "Gift credits",
                "Credits from subscription",
                "Educational credits"
              ]
          end
          |> Enum.random()

        CreditBalance.new(
          type: CreditBalanceType.value(type),
          description: description,
          amount: random_float(0, 10_000) |> Money.parse!() |> Money.to_string(),
          occured_at: Google.Protobuf.Timestamp.new(%{seconds: Timex.to_unix(occured_at)})
        )
      end

    [initial_balance | balance_history]
    |> Enum.sort_by(& &1.occured_at.seconds, :desc)
  end

  def stub(request, response) do
    DB.insert(:billing, %{
      request: request,
      response: response
    })
  end

  defp random_float(min, max) do
    min + (max - min) * :rand.uniform()
  end

  defp merge_with_defaults(defaults, params) do
    defaults = Enum.into(defaults, %{})
    params = Enum.into(params, %{})

    defaults
    |> Map.merge(params)
  end

  defmodule Grpc do
    alias InternalApi.Billing.SetupOrganizationResponse

    def init do
      GrpcMock.stub(BillingMock, :list_spendings, &__MODULE__.find/2)
      GrpcMock.stub(BillingMock, :list_spending_seats, &__MODULE__.find/2)
      GrpcMock.stub(BillingMock, :list_daily_costs, &__MODULE__.find/2)
      GrpcMock.stub(BillingMock, :list_invoices, &__MODULE__.find/2)
      GrpcMock.stub(BillingMock, :describe_spending, &__MODULE__.find/2)
      GrpcMock.stub(BillingMock, :current_spending, &__MODULE__.find/2)
      GrpcMock.stub(BillingMock, :set_budget, &__MODULE__.set_budget/2)
      GrpcMock.stub(BillingMock, :get_budget, &__MODULE__.find/2)
      GrpcMock.stub(BillingMock, :credits_usage, &__MODULE__.find/2)
      GrpcMock.stub(BillingMock, :can_upgrade_plan, &__MODULE__.can_upgrade_plan/2)
      GrpcMock.stub(BillingMock, :upgrade_plan, &__MODULE__.find/2)
      GrpcMock.stub(BillingMock, :list_projects, &__MODULE__.find/2)
      GrpcMock.stub(BillingMock, :describe_project, &__MODULE__.find/2)
      GrpcMock.stub(BillingMock, :setup_organization, &__MODULE__.setup_organization/2)
      GrpcMock.stub(BillingMock, :can_setup_organization, &__MODULE__.can_setup_organization/2)
      GrpcMock.stub(BillingMock, :acknowledge_trial_end, &__MODULE__.acknowledge_trial_end/2)
    end

    def acknowledge_trial_end(_request, _) do
      AcknowledgeTrialEndResponse.new()
    end

    def set_budget(request, _) do
      amount =
        request.budget.limit
        |> String.replace("$", "")
        |> String.replace(",", "")
        |> String.replace(" ", "")
        |> case do
          "" -> "0"
          other -> other
        end
        |> Decimal.parse()
        |> case do
          {decimal, _} ->
            {:ok, money} = Money.parse(decimal)

            money
            |> Money.to_string()

          _ ->
            raise GRPC.RPCError.exception(:internal, "error parsing money")
        end

      request = %{request | budget: %{request.budget | limit: amount}}

      DB.delete(:billing, fn row ->
        row.request == %GetBudgetRequest{org_id: request.org_id}
      end)

      DB.insert(:billing, %{
        request: %GetBudgetRequest{org_id: request.org_id},
        response: %GetBudgetResponse{
          budget: request.budget
        }
      })

      %SetBudgetResponse{
        budget: request.budget
      }
    end

    def find(request, _) do
      DB.find_by(:billing, :request, request)
      |> case do
        %{response: response} ->
          response

        _ ->
          GRPC.RPCError.exception(
            :unimplemented,
            "no stub defined for #{inspect(request)}"
          )
          |> tap(fn exception ->
            require Logger
            Logger.error(exception.message)
            raise exception
          end)
      end
    end

    def can_upgrade_plan(_request, _) do
      CanUpgradePlanResponse.new(allowed: true, errors: [])
    end

    def can_setup_organization(_request, _) do
      CanSetupOrganizationResponse.new(allowed: true, errors: [])
    end

    def setup_organization(_request, _) do
      SetupOrganizationResponse.new()
    end
  end
end
