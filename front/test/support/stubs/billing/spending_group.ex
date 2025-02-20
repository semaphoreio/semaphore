defmodule Support.Stubs.Billing.SpendingGroup do
  alias InternalApi.Billing.{
    SpendingGroup,
    SpendingItem,
    SpendingTrend,
    SpendingType
  }

  def addons(opts \\ []) do
    default_items =
      [
        {"dedicated-cache", "Dedicated cache", "500 GB, 10 GB/s", "$300.00", 1, "$300.00"}
      ]
      |> Enum.map(fn {name, display_name, description, unit_price, units, total_price} ->
        SpendingItem.new(
          name: name,
          display_name: display_name,
          display_description: description,
          unit_price: unit_price,
          units: units,
          total_price: total_price
        )
      end)

    items = Keyword.get(opts, :items, default_items)

    SpendingGroup.new(
      type: SpendingType.value(:SPENDING_TYPE_ADDON),
      items: items,
      total_price: calculate_total(items),
      trends: [
        SpendingTrend.new(
          name: "01-01-2022",
          price: "$ 300.00"
        ),
        SpendingTrend.new(
          name: "01-02-2022",
          price: "$ 250.00"
        )
      ]
    )
  end

  def machine_time(opts \\ []) do
    default_items =
      [
        {"e1-standard-2", "e1-standard-2", "2 vCPU, 4GB RAM, 25 GB disk", "$ 0.0075", 3_931,
         "$ 23.59"},
        {"e1-standard-4", "e1-standard-4", "4 vCPU, 8GB RAM, 35 GB disk", "$ 0.0150", 12_412,
         "$ 148.94"},
        {"e1-standard-8", "e1-standard-8", "8 vCPU, 16GB RAM, 45 GB disk", "$ 0.0300", 0,
         "$ 0.00"},
        {"e2-standard-2", "e2-standard-2", "2 vCPU, 8GB RAM, 55 GB disk", "$ 0.0080", 26_021,
         "$ 23.59"},
        {"e2-standard-4", "e2-standard-4", "4 vCPU, 16GB RAM, 75 GB disk", "$ 0.0180", 9_847,
         "$ 148.94"},
        {"e2-standard-8", "e2-standard-8", "8 vCPU, 32GB RAM, 100 GB disk", "$ 0.0360", 1_013,
         "$ 51.34"},
        {"s1-standard-x", "s1-standard-x", "SELF-HOSTED", "", 12_341, "$ 47.56"},
        {"s1-standard-x", "Free", "6000 max", "$ 0.00", 6000, "$ 0.00"},
        {"s1-standard-x", "Paid", "", "$ 0.0075", 6_341, "$ 47.56"}
      ]
      |> Enum.map(fn {name, display_name, description, unit_price, units, total_price} ->
        SpendingItem.new(
          name: name,
          display_name: display_name,
          display_description: description,
          unit_price: unit_price,
          units: units,
          total_price: total_price
        )
      end)

    items = Keyword.get(opts, :items, default_items)

    SpendingGroup.new(
      type: SpendingType.value(:SPENDING_TYPE_MACHINE_TIME),
      items: items,
      total_price: calculate_total(items),
      trends: [
        SpendingTrend.new(
          name: "01-01-2022",
          price: "$ 1267.66"
        ),
        SpendingTrend.new(
          name: "01-02-2022",
          price: "$ 1468.66"
        )
      ]
    )
  end

  def machine_capacity(opts \\ []) do
    default_items =
      [
        {"e1-standard-2", "e1-standard-2", "2 vCPU, 4GB RAM, 25 GB disk", "$ 0.00", 25, "$ 0.00"},
        {"e1-standard-4", "e1-standard-4", "4 vCPU, 8GB RAM, 35 GB disk", "$ 0.00", 10, "$ 0.00"},
        {"e1-standard-8", "e1-standard-8", "8 vCPU, 16GB RAM, 45 GB disk", "$ 0.00", 0, "$ 0.00"},
        {"e2-standard-2", "e2-standard-2", "2 vCPU, 8GB RAM, 55 GB disk", "$ 0.00", 15, "$ 0.00"},
        {"e2-standard-4", "e2-standard-4", "4 vCPU, 16GB RAM, 75 GB disk", "$ 0.00", 20,
         "$ 0.00"},
        {"e2-standard-8", "e2-standard-8", "8 vCPU, 32GB RAM, 100 GB disk", "$ 0.00", 30,
         "$ 0.00"},
        {"s1-standard-x", "s1-standard-x", "SELF-HOSTED", "$ 0.00", 12_341, "$ 0.00"}
      ]
      |> Enum.map(fn {name, display_name, description, unit_price, units, total_price} ->
        SpendingItem.new(
          name: name,
          display_name: display_name,
          display_description: description,
          unit_price: unit_price,
          units: units,
          total_price: total_price
        )
      end)

    items = Keyword.get(opts, :items, default_items)

    SpendingGroup.new(
      type: SpendingType.value(:SPENDING_TYPE_MACHINE_CAPACITY),
      items: items,
      total_price: calculate_total(items)
    )
  end

  def seats(opts \\ []) do
    default_items =
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

    items = Keyword.get(opts, :items, default_items)

    SpendingGroup.new(
      type: SpendingType.value(:SPENDING_TYPE_SEAT),
      items: items,
      total_price: calculate_total(items)
    )
  end

  def storage(opts \\ []) do
    default_items =
      [
        {"artifacts-storage", "Artifacts Storage", "", "", 245, "$ 12.95"},
        {"artifacts-storage", "Free", "60 max", "$ 0.00", 60, "$ 0.00"},
        {"artifacts-storage", "Paid", "", "$ 0.07", 185, "$ 12.95"},
        {"artifacts-egress", "Artifacts Egress", "", "", 190, "$ 4.55"},
        {"artifacts-egress", "Free", "30 max", "$ 0.00", 30, "$ 0.00"},
        {"artifacts-egress", "Paid", "", "$ 0.035", 130, "$ 4.55"},
        {"cache-egress", "Cache Egress", "", "$0.005", 745, "$3.50"}
      ]
      |> Enum.map(fn {name, display_name, description, unit_price, units, total_price} ->
        SpendingItem.new(
          name: name,
          display_name: display_name,
          display_description: description,
          unit_price: unit_price,
          units: units,
          total_price: total_price
        )
      end)

    items = Keyword.get(opts, :items, default_items)

    SpendingGroup.new(
      type: SpendingType.value(:SPENDING_TYPE_STORAGE),
      items: items,
      total_price: calculate_total(items),
      trends: [
        SpendingTrend.new(
          name: "01-01-2022",
          price: "$ 22.66"
        ),
        SpendingTrend.new(
          name: "01-02-2022",
          price: "$ 25.66"
        )
      ]
    )
  end

  def item(opts) do
    defaults = [
      display_description: "",
      units: 0,
      unit_price: "$0.00",
      total_price: "$0.00",
      name: "an-item",
      trends: [],
      enabled: true
    ]

    params = Keyword.merge(defaults, opts)

    params =
      [
        display_name: params[:name] |> String.replace("-", " ") |> String.capitalize()
      ]
      |> Keyword.merge(params)

    SpendingItem.new(params)
  end

  @spec calculate_total([SpendingItem.t()]) :: String.t()
  def calculate_total(items) do
    items
    |> Enum.reduce(Money.new(0), fn item, sum ->
      price = Money.parse!(item.total_price)
      Money.add(sum, price)
    end)
    |> Money.to_string()
  end
end
