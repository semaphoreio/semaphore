defmodule Front.Models.Billing.SpendingTest do
  use ExUnit.Case, async: true

  alias Front.Models.Billing.{Spending, SpendingGroup, SpendingItem}

  describe "to_csv/1" do
    test "renders a header row followed by one row per spending item" do
      csv = Spending.to_csv(spending())

      assert [header | rows] = lines(csv)
      assert header == "type,name,units,unit_price,total_price"

      assert rows == [
               "machine_time,e1-standard-2,100,$ 0.0075,$ 0.75",
               "machine_time,e1-standard-4,20,$ 0.0150,$ 0.30",
               "seats,Paid,3,$ 5.00,$ 15.00"
             ]
    end

    test "renders only the header when every group is empty" do
      csv = Spending.to_csv(spending(groups: [group(:seats, [])]))

      assert lines(csv) == ["type,name,units,unit_price,total_price"]
    end

    test "escapes values carrying CSV metacharacters instead of breaking the row" do
      item = item(~s(Paid, "pro" tier), 1, "$ 5.00", "$ 5.00")
      csv = Spending.to_csv(spending(groups: [group(:seats, [item])]))

      assert lines(csv) == [
               "type,name,units,unit_price,total_price",
               ~s(seats,"Paid, ""pro"" tier",1,$ 5.00,$ 5.00)
             ]
    end
  end

  defp spending(overrides \\ []) do
    defaults = [
      id: "spending-id",
      display_name: "Hybrid 01 Oct - 31 Oct, 2026",
      groups: [
        group(:machine_time, [
          item("e1-standard-2", 100, "$ 0.0075", "$ 0.75"),
          item("e1-standard-4", 20, "$ 0.0150", "$ 0.30")
        ]),
        group(:seats, [item("Paid", 3, "$ 5.00", "$ 15.00")])
      ]
    ]

    struct(Spending, Keyword.merge(defaults, overrides))
  end

  defp group(type, items) do
    %SpendingGroup{type: type, items: items, total_price: "$ 0.00"}
  end

  defp item(display_name, units, unit_price, total_price) do
    %SpendingItem{
      name: display_name,
      display_name: display_name,
      units: units,
      unit_price: unit_price,
      total_price: total_price
    }
  end

  defp lines(csv), do: csv |> String.split("\r\n", trim: true)
end
