defmodule Test.Support.WorkflowBuilder.Test do
  use Ppl.IntegrationCase

  alias Test.Support.WorkflowBuilder

  setup do
    Test.Helpers.truncate_db()

    urls = %{workflow_service: "localhost:50053", plumber_service: "localhost:50053"}
    start_supervised!({WorkflowBuilder.Impl, urls})
    :ok
  end

  @tag :integration
  test "build workflow and get valid description" do
    Test.Helpers.start_all_loopers()

    topology = [{:schedule, nil}, {:schedule_extension, 0}, {:partial_rebuild, 1},
                {:schedule_extension, 0}, {:partial_rebuild, 3},  {:schedule_extension, 2}]

    result = WorkflowBuilder.build(topology)

    ppl_6 = %{ppl_id: get_id(result, 5), extensions: [], partial_rebuilds: []}
    ppl_5 = %{ppl_id: get_id(result, 4), extensions: [], partial_rebuilds: []}
    ppl_4 = %{ppl_id: get_id(result, 3), extensions: [], partial_rebuilds: [ppl_5]}
    ppl_3 = %{ppl_id: get_id(result, 2), extensions: [ppl_6], partial_rebuilds: []}
    ppl_2 = %{ppl_id: get_id(result, 1), extensions: [], partial_rebuilds: [ppl_3]}
    ppl_1 = %{ppl_id: get_id(result, 0), extensions: [ppl_2, ppl_4], partial_rebuilds: []}

    wf_id = result |> Enum.at(0) |> elem(1)
    assert WorkflowBuilder.describe(wf_id) == ppl_1
  end

  defp get_id(list, index), do: list |> Enum.at(index) |> elem(2)
end
