defmodule Test.Actions.DescribeImpl.Test do
  use ExUnit.Case

  alias Test.Actions.DescribeImpl
  alias Scheduler.Actions.DescribeImpl
  alias Scheduler.Periodics.Model.PeriodicsQueries

  test "describe works with periodics with parameters" do
    assert {:ok, periodics} =
             PeriodicsQueries.insert(%{
               requester_id: UUID.uuid4(),
               organization_id: UUID.uuid4(),
               name: "Periodic_1",
               project_name: "Project_1",
               project_id: UUID.uuid4(),
               recurring: true,
               reference: "master",
               at: "* * * * *",
               pipeline_file: "deploy.yml",
               parameters: [
                 %{name: "param1", required: true, default_value: "value1", options: ["v1", "v2"]}
               ]
             })

    assert {:ok, _} = DescribeImpl.describe(%{id: periodics.id})
  end
end
