defmodule Ppl.DefinitionReviser.Task2BuildTest do
  use ExUnit.Case
  doctest(Ppl.DefinitionReviser.Task2Build, [import: true])

  alias Ppl.DefinitionReviser.Task2Build

  setup do
    blocks = [%{"name" => "block 1", "task" => %{"jobs" => [%{"name" => "a"}]}},
              %{"name" => "block 2", "task" => %{}},
              %{"name" => "block 3", "build" => %{}}
             ]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    ppl_def = %{"agent" => agent, "blocks" => blocks}
    ppl = %{ppl_id: "Pipeline's UUID"}
    {:ok, %{ppl: ppl, ppl_def: ppl_def}}
  end

  test "rename", ctx do
    expected = ctx.ppl_def |> Map.put("blocks",
      [%{"name" => "block 1", "build" => %{"jobs" => [%{"name" => "a"}]}},
       %{"name" => "block 2", "build" => %{}},
       %{"name" => "block 3", "build" => %{}}]
    )
    assert(Task2Build.rename(ctx.ppl_def) == {:ok, expected})
  end
end
