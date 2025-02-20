defmodule Support.Stubs.Billing.Project do
  alias Support.Stubs

  alias InternalApi.Billing.{
    Project,
    ProjectCost,
    SpendingGroup,
    SpendingItem
  }

  def project(opts \\ []) do
    id = Keyword.get(opts, :id, Ecto.UUID.generate())
    name = Keyword.get(opts, :name, "Project #{id}")
    cost = Keyword.get(opts, :cost, project_cost())

    Project.new(
      id: id,
      name: name,
      cost: cost
    )
  end

  def project_with_costs(project, opts \\ []) do
    {from_date, to_date} = interval_from_opts(opts)

    costs =
      Timex.Interval.new(from: from_date, until: to_date, right_open: false)
      |> Enum.map(fn day ->
        daily_total = random_float(0, 1200)
        workflow_count = floor(daily_total / 2.0)

        machine_time_items =
          [
            Stubs.Billing.SpendingGroup.item(
              name: "e1-standard-2",
              display_name: "e1-standard-2",
              unit_price: "$0.005"
            ),
            Stubs.Billing.SpendingGroup.item(
              name: "e1-standard-4",
              display_name: "e1-standard-4",
              unit_price: "$0.007"
            ),
            Stubs.Billing.SpendingGroup.item(
              name: "e1-standard-8",
              display_name: "e1-standard-8",
              unit_price: "$0.009"
            ),
            Stubs.Billing.SpendingGroup.item(
              name: "s1-x",
              display_name: "s1-x",
              unit_price: "$0.0005"
            ),
            Stubs.Billing.SpendingGroup.item(
              name: "e2-standard-2",
              display_name: "e2-standard-2",
              total_price: "$0.00"
            )
          ]
          |> distribute_usage(100, 1000)

        machine_time_group = Stubs.Billing.SpendingGroup.machine_time(items: machine_time_items)

        storage_items =
          [
            Stubs.Billing.SpendingGroup.item(
              name: "artifact-egress",
              unit_price: "$0.0003"
            ),
            Stubs.Billing.SpendingGroup.item(
              name: "artifact-storage",
              unit_price: "$0.0001"
            ),
            Stubs.Billing.SpendingGroup.item(
              name: "cache-egress",
              unit_price: "$0.0005"
            )
          ]
          |> distribute_usage(1000, 10_000)

        storage_group = Stubs.Billing.SpendingGroup.storage(items: storage_items)

        day
        |> Timex.to_date()
        |> then(& &1.day)
        |> case do
          day_no when day_no > 11 ->
            nil

          _day_no ->
            ProjectCost.new(
              from_date: Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(day)),
              to_date:
                Google.Protobuf.Timestamp.new(
                  seconds: Timex.shift(day, days: 1) |> Timex.to_unix()
                ),
              workflow_count: workflow_count,
              workflow_trends: [],
              total_price:
                Stubs.Billing.SpendingGroup.calculate_total(machine_time_items ++ storage_items),
              spending_groups: [
                machine_time_group,
                storage_group
              ]
            )
        end
      end)
      |> Enum.filter(& &1)

    [first_cost | rest_costs] = costs

    cost =
      rest_costs
      |> Enum.reduce(first_cost, fn project_cost, summary_cost ->
        combine_project_costs(summary_cost, project_cost)
      end)

    cost = %{
      cost
      | from_date: Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(from_date)),
        to_date: Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(to_date))
    }

    {%{project | cost: cost}, costs}
  end

  defp combine_project_costs(cost1, cost2) do
    total_price =
      Money.add(Money.parse!(cost1.total_price), Money.parse!(cost2.total_price))
      |> Money.to_string()

    %ProjectCost{
      from_date: cost1.from_date,
      to_date: cost2.to_date,
      workflow_count: cost1.workflow_count + cost2.workflow_count,
      workflow_trends: [],
      total_price: total_price,
      spending_groups: combine_spending_groups(cost1.spending_groups, cost2.spending_groups)
    }
  end

  defp combine_spending_groups(groups1, groups2) do
    groups1
    |> Enum.reduce(groups2, fn group1, groups2 ->
      group2 = Enum.find(groups2, fn group2 -> group1.type == group2.type end)
      combined_group = combine_spending_group(group1, group2)
      type = combined_group.type

      groups2
      |> Enum.map(fn
        %{type: ^type} -> combined_group
        group -> group
      end)
    end)
  end

  defp combine_spending_group(group1, group2) do
    total_price =
      Money.add(Money.parse!(group1.total_price), Money.parse!(group2.total_price))
      |> Money.to_string()

    %SpendingGroup{
      type: group1.type,
      total_price: total_price,
      items: combine_spending_group_items(group1.items, group2.items),
      trends: []
    }
  end

  defp combine_spending_group_items(items1, items2) do
    items1
    |> Enum.reduce(items2, fn item1, items2 ->
      item2 = Enum.find(items2, fn item2 -> item1.name == item2.name end)

      if item2 do
        combined_item = combine_spending_group_item(item1, item2)
        name = combined_item.name

        items2
        |> Enum.map(fn
          %{name: ^name} -> combined_item
          item -> item
        end)
      else
        items2 ++ [item1]
      end
    end)
  end

  defp combine_spending_group_item(item1, item2) do
    total_price =
      Money.add(Money.parse!(item1.total_price), Money.parse!(item2.total_price))
      |> Money.to_string()

    %SpendingItem{
      name: item1.name,
      display_name: item1.display_name,
      display_description: item1.display_description,
      total_price: total_price,
      unit_price: item1.unit_price,
      units: item1.units + item2.units,
      trends: item1.trends,
      enabled: item1.enabled
    }
  end

  def project_cost(opts \\ []) do
    {from_date, to_date} = interval_from_opts(opts)
    total_price = Keyword.get(opts, :total_price, "$ 100.00")
    workflow_count = Keyword.get(opts, :workflow_count, 1)
    workflow_trends = Keyword.get(opts, :workflow_trends, [])
    spending_groups = Keyword.get(opts, :spending_groups, [])

    ProjectCost.new(
      from_date: Google.Protobuf.Timestamp.new(seconds: from_date.second),
      to_date: Google.Protobuf.Timestamp.new(seconds: to_date.second),
      total_price: total_price,
      workflow_count: workflow_count,
      workflow_trends: workflow_trends,
      spending_groups: spending_groups
    )
  end

  defp interval_from_opts(opts) do
    from_date = Keyword.get(opts, :from_date, Timex.now())
    to_date = Keyword.get(opts, :to_date, Timex.now())
    {from_date, to_date}
  end

  defp random_float(min, max) do
    min + (max - min) * :rand.uniform()
  end

  defp distribute_usage(items, min, max) do
    items
    |> Enum.map(fn item ->
      units = Enum.random(min..max)
      {unit_price, _} = item.unit_price |> String.replace("$", "") |> Decimal.parse()

      total = Decimal.mult(unit_price, units) |> Money.parse!() |> Money.to_string()

      %{item | units: units, total_price: total}
    end)
  end
end
