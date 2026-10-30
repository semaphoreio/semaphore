defmodule Front.Models.Billing.ProjectSpendingTest do
  use ExUnit.Case, async: true

  alias Front.Models.Billing.{Project, ProjectCost, ProjectSpending, SpendingGroup}

  doctest Front.Models.Billing.ProjectSpending

  describe "to_csv/1" do
    test "renders a row per spending group, then a workflow count row per project" do
      csv = ProjectSpending.to_csv([project("zebra"), project("front")])

      assert [header | rows] = lines(csv)
      assert header == "project_name,type,price"

      assert rows == [
               "zebra,machine_time,$ 23.59",
               "zebra,storage,$ 12.95",
               "front,machine_time,$ 23.59",
               "front,storage,$ 12.95",
               "zebra,workflow_count,123",
               "front,workflow_count,123"
             ]
    end

    test "renders only the header for an empty project list" do
      assert lines(ProjectSpending.to_csv([])) == ["project_name,type,price"]
    end

    test "escapes project names carrying CSV metacharacters instead of breaking the row" do
      csv = ProjectSpending.to_csv([project(~s(a,b "c"), groups: [])])

      assert lines(csv) == [
               "project_name,type,price",
               ~s("a,b ""c""",workflow_count,123)
             ]
    end
  end

  defp project(name, overrides \\ []) do
    groups =
      Keyword.get(overrides, :groups, [
        %SpendingGroup{type: :machine_time, total_price: "$ 23.59"},
        %SpendingGroup{type: :storage, total_price: "$ 12.95"}
      ])

    %Project{
      id: "id-#{name}",
      name: name,
      cost: %ProjectCost{
        total_price: "$ 36.54",
        workflow_count: 123,
        spending_groups: groups
      }
    }
  end

  defp lines(csv), do: csv |> String.split("\r\n", trim: true)
end
