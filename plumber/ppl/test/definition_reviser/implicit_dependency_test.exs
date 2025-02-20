defmodule Ppl.DefinitionReviser.ImplicitDependency.Test do
  use Ppl.IntegrationCase

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Actions

  setup do
    Test.Helpers.truncate_db()
    {:ok, %{}}
  end

  @tag :integration
  test "convert implicit into explicit dependencies" do

  {:ok, %{ppl_id: ppl_id}} =
    %{"repo_name" => "5_v1_full", "file_name" =>"no_cmd_files.yml"}
    |> Test.Helpers.schedule_request_factory(:local)
    |> Actions.schedule()

    loopers = start_loopers()

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "pending", 7_000)

    {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)
    %{definition: definition} = ppl_req

    stop_loopers(loopers)

    definition
    |> get_deps()
    |> check_deps()

  end

  defp get_deps(definition) do
    definition
    |> Map.get("blocks")
    |> Enum.map(fn block -> %{block["name"] => block["dependencies"]} end)
  end

  defp check_deps(list) do
    b1 = hd(list)
    b2 = hd(tl(list))
    assert Map.get(b1, "Block 1") == []
    assert Map.get(b2, "Block 2") == ["Block 1"]
  end


  defp start_loopers() do
    []
    # Ppls loopers
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    # PplSubInits loopers
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])
  end

  defp stop_loopers(loopers) do
    loopers |> Enum.map(fn {:ok, pid} -> GenServer.stop(pid) end)
  end

end
