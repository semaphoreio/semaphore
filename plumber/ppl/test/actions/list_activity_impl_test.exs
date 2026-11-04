defmodule Ppl.Actions.ListActivityImpl.Test do
  use Ppl.IntegrationCase

  import Ecto.Query

  alias Ppl.Actions.{DescribeTopologyImpl, ListActivityImpl}
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplBlocks.Model.{PplBlocks, PplBlocksQueries}
  alias Ppl.PplRequests.Model.{PplRequests, PplRequestsQueries}
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.PplTraces.Model.PplTracesQueries

  @org_id "list-activity-org"
  @big_marker "LARGE_DEFINITION_PAYLOAD"

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  test "job names per block match the topology of the full definition" do
    definitions = [
      definition([
        block("plain", [job("a"), job("b")]),
        block("matrix", [
          job("m", %{
            "matrix" => [
              %{"env_var" => "ERLANG", "values" => ["24", "25"]},
              %{"env_var" => "ELIXIR", "values" => ["1.14", "1.15"]}
            ]
          })
        ]),
        block("parallel", [job("p", %{"parallelism" => 4}), job("after p")])
      ]),
      definition([
        block("job count env with matrix", [
          job("c", %{
            "env_vars" => [
              %{"name" => "FOO", "value" => "bar"},
              %{"name" => "SEMAPHORE_JOB_COUNT", "value" => "2"}
            ],
            "matrix" => [%{"env_var" => "IDX", "values" => ["1", "2"]}]
          })
        ]),
        block("boosters", [job("regular")], %{
          "boosters" => [%{"name" => "rspec", "type" => "rspec", "job_count" => 3}]
        }),
        block("no jobs", [])
      ]),
      definition([
        %{"name" => "unnamed job", "build" => %{"jobs" => [%{"commands" => ["echo"]}]}}
      ]),
      definition([
        block("first", [job("a")], %{}, []),
        block("second", [job("b")], %{}, ["first"]),
        block("third", [job("c")], %{}, ["first", "second"]),
        block("no deps key", [job("d")])
      ]),
      definition([
        block("parallelism and matrix", [
          job("pm", %{
            "parallelism" => 3,
            "matrix" => [%{"env_var" => "IGNORED", "values" => ["x", "y"]}]
          })
        ]),
        block("software versions", [
          job("sv", %{
            "matrix" => [
              %{"software" => "Elixir", "versions" => ["1.14", "1.15"]},
              %{"env_var" => "DB", "values" => ["pg", "mysql"]}
            ]
          })
        ]),
        block("bl\u00f6ck \u2713 \u69cb\u7bc9", [
          job("j\u00f6b \u30c6\u30b9\u30c8", %{
            "matrix" => [%{"env_var" => "\u00c9", "values" => ["\u00e0", "\u00fc"]}]
          })
        ])
      ])
    ]

    ppls = Enum.map(definitions, &insert_active_ppl/1)

    # mark first block of every pipeline as running so job statuses differ
    ppls |> Enum.each(fn {ppl, _} -> set_block_state(ppl.ppl_id, 0, "running") end)

    assert {:ok, %{pipelines: result}} = list_activity()

    # newest pipeline first, and every pipeline only carries its own blocks
    assert Enum.map(result, & &1.ppl_id) ==
             ppls |> Enum.reverse() |> Enum.map(fn {ppl, _} -> ppl.ppl_id end)

    Enum.each(ppls, fn {ppl, definition} ->
      pipeline = Enum.find(result, &(&1.ppl_id == ppl.ppl_id))
      assert_same_jobs(pipeline, definition)
      assert_same_blocks(pipeline, definition)

      refute Map.has_key?(pipeline, :definition)
      assert pipeline.definition_file == ".semaphore/semaphore.yml"
    end)

    [_, booster_ppl, _, deps_ppl, _] = ppls |> Enum.map(fn {ppl, _} -> ppl.ppl_id end)
    booster_result = Enum.find(result, &(&1.ppl_id == booster_ppl))

    assert ["job count env with matrix", "boosters", "no jobs"] ==
             Enum.map(booster_result.blocks, & &1.name)

    assert [first | _] = booster_result.blocks

    assert Enum.map(first.jobs, & &1.name) == ["c - 1/2", "c - 2/2"]
    assert Enum.all?(first.jobs, &(&1.status == "scheduled"))

    assert booster_result.blocks |> Enum.at(1) |> Map.get(:jobs) |> Enum.map(& &1.name) ==
             ["regular", "rspec rspec1", "rspec rspec2", "rspec rspec3"]

    assert booster_result.blocks
           |> Enum.at(1)
           |> Map.get(:jobs)
           |> Enum.all?(&(&1.status == "pending"))

    assert booster_result.blocks |> Enum.at(2) |> Map.get(:jobs) == []

    deps_result = Enum.find(result, &(&1.ppl_id == deps_ppl))

    assert Enum.map(deps_result.blocks, & &1.dependencies) ==
             [[], ["first"], ["first", "second"], nil]
  end

  test "gRPC response carries the same block details" do
    {ppl, definition} =
      insert_active_ppl(
        definition([
          block("first", [job("a", %{"parallelism" => 2})], %{}, []),
          block("second", [job("b")], %{}, ["first"]),
          block("no deps key", [job("c")])
        ])
      )

    set_block_state(ppl.ppl_id, 0, "running")

    {:ok, %{blocks: topology}} = DescribeTopologyImpl.describe_topology(definition)

    assert %{pipelines: [pipeline]} = grpc_list_activity()
    assert pipeline.ppl_id == ppl.ppl_id

    assert Enum.map(pipeline.blocks, &{&1.name, &1.dependencies}) ==
             Enum.map(topology, &{&1.name, &1.dependencies || []})

    assert Enum.map(pipeline.blocks, fn b -> Enum.map(b.jobs, &{&1.name, &1.index, &1.status}) end) ==
             [
               [{"a - 1/2", 0, "scheduled"}, {"a - 2/2", 1, "scheduled"}],
               [{"b", 0, "pending"}],
               [{"c", 0, "pending"}]
             ]

    assert Enum.map(pipeline.blocks, & &1.state) == [:RUNNING, :INITIALIZING, :INITIALIZING]
  end

  test "wide pipeline keeps block order and each block gets its own jobs" do
    blocks =
      for i <- 1..150 do
        deps = if i == 1, do: [], else: ["block #{i - 1}"]
        block("block #{i}", [job("job #{i}", %{"parallelism" => rem(i, 3) + 1})], %{}, deps)
      end

    {ppl, definition} = insert_active_ppl(definition(blocks))
    set_block_state(ppl.ppl_id, 7, "running")

    assert {:ok, %{pipelines: [pipeline]}} = list_activity()
    assert length(pipeline.blocks) == 150
    assert_same_jobs(pipeline, definition)
    assert_same_blocks(pipeline, definition)

    assert Enum.map(pipeline.blocks, & &1.name) == Enum.map(1..150, &"block #{&1}")
    assert pipeline.blocks |> Enum.at(7) |> Map.get(:jobs) |> Enum.map(& &1.status) |> Enum.uniq() == ["scheduled"]
  end

  test "pipeline without a definition is listed with no blocks" do
    {with_def, definition} = insert_active_ppl(definition([block("b", [job("a")], %{}, [])]))
    {without_def, _} = insert_active_ppl(definition([block("b", [job("a")])]))

    from(pb in PplBlocks, where: pb.ppl_id == ^without_def.ppl_id) |> Repo.delete_all()

    from(pr in PplRequests, where: pr.id == ^without_def.ppl_id)
    |> Repo.update_all(set: [definition: nil])

    assert {:ok, %{pipelines: result}} = list_activity()
    assert Enum.map(result, & &1.ppl_id) == [without_def.ppl_id, with_def.ppl_id]

    assert Enum.find(result, &(&1.ppl_id == without_def.ppl_id)).blocks == []
    assert_same_blocks(Enum.find(result, &(&1.ppl_id == with_def.ppl_id)), definition)
  end

  test "definition is projected only for pipelines on the requested page" do
    for _ <- 1..3, do: insert_active_ppl(definition([block("b", [job("a")])]))

    rows =
      capture_query_rows(fn ->
        assert {:ok, %{pipelines: [_]}} = list_activity(1)
      end)

    projected = Enum.filter(rows, &match?([_, %{"blocks" => _}], &1))
    assert length(projected) == 1
  end

  test "full definition is not loaded from the database" do
    big_commands = for i <- 1..2_000, do: "echo #{@big_marker} #{i}"

    big_definition =
      definition([
        block("big", [
          job("j1", %{
            "commands" => big_commands,
            "env_vars" => [%{"name" => "SECRET_LIKE", "value" => @big_marker}]
          }),
          job("j2", %{"parallelism" => 2, "commands" => big_commands})
        ])
      ])
      |> Map.put("after_pipeline", [
        %{"build" => %{"jobs" => [job("ap", %{"commands" => big_commands})]}}
      ])
      |> Map.put("global_job_config", %{"prologue" => %{"commands" => big_commands}})

    {ppl, _} = insert_active_ppl(big_definition)

    rows = capture_query_rows(fn -> assert {:ok, %{pipelines: [_]}} = list_activity() end)

    assert rows != []

    refute rows
           |> inspect(limit: :infinity, printable_limit: :infinity)
           |> String.contains?(@big_marker)

    assert {:ok, %{pipelines: [result]}} = list_activity()
    assert result.ppl_id == ppl.ppl_id
    assert_same_jobs(result, big_definition)

    assert result.blocks |> hd() |> Map.get(:jobs) |> Enum.map(& &1.name) == [
             "j1",
             "j2 - 1/2",
             "j2 - 2/2"
           ]
  end

  # ListActivity never uses after_pipeline. Reading it from the full definition
  # used to raise on an empty list and fail the whole page on an invalid matrix.
  for {label, after_pipeline} <- [
        {"empty", []},
        {"invalid matrix", [%{"build" => %{"jobs" => [%{"name" => "ap", "matrix" => []}]}}]}
      ] do
    test "after_pipeline does not affect the listing: #{label}" do
      blocks = [block("b", [job("a")])]
      {ok, _} = insert_active_ppl(definition(blocks))

      {other, _} =
        definition(blocks)
        |> Map.put("after_pipeline", unquote(Macro.escape(after_pipeline)))
        |> insert_active_ppl()

      assert {:ok, %{pipelines: result}} = list_activity()
      assert Enum.map(result, & &1.ppl_id) == [other.ppl_id, ok.ppl_id]
      assert Enum.all?(result, &match?([%{name: "b", jobs: [%{name: "a"}]}], &1.blocks))
    end
  end

  test "pipelines from other organizations and finished pipelines are not listed" do
    {ppl, _} = insert_active_ppl(definition([block("b", [job("a")])]))
    {other_org, _} = insert_active_ppl(definition([block("b", [job("a")])]), "other-org")
    {done, _} = insert_active_ppl(definition([block("b", [job("a")])]))
    set_ppl_state(done.ppl_id, "done")

    assert {:ok, %{pipelines: result}} = list_activity()
    ids = Enum.map(result, & &1.ppl_id)

    assert ids == [ppl.ppl_id]
    refute other_org.ppl_id in ids
  end

  # Helpers

  defp list_activity(page_size \\ 30) do
    ListActivityImpl.list_activity_sql(@org_id, %{
      page_token: nil,
      direction: :NEXT,
      page_size: page_size,
      order: :BY_CREATION_TIME_DESC
    })
  end

  defp assert_same_jobs(pipeline, definition) do
    {:ok, %{blocks: expected}} = DescribeTopologyImpl.describe_topology(definition)

    assert Enum.map(pipeline.blocks, & &1.name) == Enum.map(expected, & &1.name)

    pipeline.blocks
    |> Enum.zip(expected)
    |> Enum.each(fn {block, expected_block} ->
      assert Enum.map(block.jobs, & &1.name) == expected_block.jobs
      expected_indexes = expected_block.jobs |> Enum.with_index() |> Enum.map(&elem(&1, 1))
      assert Enum.map(block.jobs, & &1.index) == expected_indexes
    end)
  end

  # Rebuilds the blocks the way they were built from the full definition:
  # topology of the whole definition merged with the pipeline_blocks rows.
  defp assert_same_blocks(pipeline, definition) do
    {:ok, %{blocks: topology}} = DescribeTopologyImpl.describe_topology(definition)
    {:ok, rows} = PplBlocksQueries.all_blocks_from_pipelines([pipeline.ppl_id])

    expected =
      Enum.map(rows, fn row ->
        block = topology |> Enum.find(&(&1.name == row.name)) |> Map.merge(row)
        status = if block.state in ["running", "done"], do: "scheduled", else: "pending"

        jobs =
          block.jobs
          |> Enum.with_index()
          |> Enum.map(fn {name, index} -> %{name: name, index: index, status: status} end)

        Map.put(block, :jobs, jobs)
      end)

    assert pipeline.blocks == expected
  end

  defp grpc_list_activity do
    request =
      %{organization_id: @org_id, page_token: "", page_size: 30}
      |> Util.Proto.deep_new!(InternalApi.Plumber.ListActivityRequest)

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")

    assert {:ok, response} =
             InternalApi.Plumber.PipelineService.Stub.list_activity(channel, request)

    Util.Proto.to_map!(response)
  end

  defp capture_query_rows(fun) do
    test_pid = self()
    handler_id = "list-activity-test-#{inspect(make_ref())}"

    :telemetry.attach(
      handler_id,
      [:ppl, :ecto_repo, :query],
      fn _event, _measurements, metadata, _ ->
        case metadata do
          %{result: {:ok, %{rows: rows}}} when is_list(rows) -> send(test_pid, {:rows, rows})
          _ -> :ok
        end
      end,
      nil
    )

    try do
      fun.()
    after
      :telemetry.detach(handler_id)
    end

    collect_rows([])
  end

  defp collect_rows(acc) do
    receive do
      {:rows, rows} -> collect_rows(acc ++ rows)
    after
      0 -> acc
    end
  end

  defp definition(blocks) do
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    %{"version" => "v1.0", "agent" => agent, "blocks" => blocks}
  end

  defp block(name, jobs, build_extra \\ %{}, dependencies \\ :none)

  defp block(name, jobs, build_extra, :none) do
    %{"name" => name, "build" => Map.merge(%{"jobs" => jobs}, build_extra)}
  end

  defp block(name, jobs, build_extra, dependencies) do
    name |> block(jobs, build_extra, :none) |> Map.put("dependencies", dependencies)
  end

  defp job(name, extra \\ %{}) do
    Map.merge(%{"name" => name, "commands" => ["echo #{name}"]}, extra)
  end

  defp insert_active_ppl(definition, org_id \\ @org_id) do
    request_args =
      %{
        "organization_id" => org_id,
        "project_id" => "123",
        "working_dir" => ".semaphore",
        "file_name" => "semaphore.yml",
        "request_token" => UUID.uuid4()
      }
      |> Test.Helpers.schedule_request_factory(:local)

    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)
    assert {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)
    assert {:ok, ppl} = PplsQueries.insert(ppl_req)
    assert {:ok, _ppl_trace} = PplTracesQueries.insert(ppl)

    assert {:ok, _} =
             Ecto.Multi.new()
             |> PplBlocksQueries.multi_insert(ppl_req)
             |> Repo.transaction()

    from(p in Ppls, where: p.ppl_id == ^ppl.ppl_id)
    |> Repo.update_all(set: [state: "running", wf_number: 1])

    {ppl, definition}
  end

  defp set_ppl_state(ppl_id, state) do
    from(p in Ppls, where: p.ppl_id == ^ppl_id)
    |> Repo.update_all(set: [state: state])
  end

  defp set_block_state(ppl_id, index, state) do
    from(pb in PplBlocks, where: pb.ppl_id == ^ppl_id and pb.block_index == ^index)
    |> Repo.update_all(set: [state: state])
  end
end
