defmodule Ppl.WorkflowQueries.KeysetGitRefTypeIndexTest do
  @moduledoc """
  Project-page listings filtered by git ref type rely on the index from
  20261029120000_add_pipeline_requests_project_id_git_ref_type_index.
  """
  use ExUnit.Case

  alias Ppl.EctoRepo, as: Repo
  alias Ppl.WorkflowQueries, as: WQ

  @index "pipeline_requests_project_id_git_ref_type_inserted_at_id"
  @telemetry_event [:ppl, :ecto_repo, :query]
  @page_size 10

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  test "index exists, is valid and has the expected definition" do
    indexdef = index_def(@index)

    assert indexdef =~ "ON public.pipeline_requests USING btree"

    assert indexdef =~
             "((request_args ->> 'project_id'::text)), ((source_args ->> 'git_ref_type'::text)), inserted_at DESC, id DESC"

    assert indexdef =~ "WHERE (initial_request = true)"
    assert valid?(@index)
  end

  # Under a generic plan `= ANY($n)` cannot use the index ordering, so Postgres
  # reads every row of that ref type and sorts; a scalar `= $n` stops at the limit.
  test "single ref type is compared as a scalar" do
    %{sql: sql, params: params} = keyset_query(["pr"])

    assert sql =~ ~r/p0\."source_args"->>'git_ref_type' = \$\d+/, sql
    refute sql =~ "ANY", sql
    assert "pr" in params
  end

  test "multiple ref types are compared as an array" do
    %{sql: sql, params: params} = keyset_query(["branch", "pr"])

    assert sql =~ ~r/p0\."source_args"->>'git_ref_type' = ANY\(\$\d+\)/, sql
    assert ["branch", "pr"] in params
  end

  test "single ref type returns only that type, newest first" do
    project_id = UUID.uuid4()

    {workflows, next_token} =
      in_rolled_back_tx(fn ->
        seed(project_id, branch: 30, pr: 15)

        {:ok, %{workflows: workflows, next_page_token: next_token}} = list(project_id, ["pr"])

        {workflows, next_token}
      end)

    assert length(workflows) == @page_size
    assert Enum.all?(workflows, &String.starts_with?(&1.branch_name, "pull-request-"))
    assert workflows == Enum.sort_by(workflows, & &1.inserted_at, {:desc, NaiveDateTime})
    assert next_token != ""
  end

  test "multiple ref types still return every requested type" do
    project_id = UUID.uuid4()

    workflows =
      in_rolled_back_tx(fn ->
        seed(project_id, branch: 3, pr: 3, tag: 3)

        {:ok, %{workflows: workflows}} = list(project_id, ["branch", "pr"])
        workflows
      end)

    assert length(workflows) == 6
    refute Enum.any?(workflows, &String.starts_with?(&1.branch_name, "refs/tags/"))
  end

  defp list(project_id, git_ref_types) do
    params = %{
      org_id: :skip,
      projects: :skip,
      project_id: project_id,
      requesters: :skip,
      requester_id: :skip,
      label: :skip,
      git_ref_types: git_ref_types,
      branch_name: :skip,
      triggerers: :skip,
      created_before: :skip,
      created_after: :skip
    }

    keyset_params = %{
      order: :BY_CREATION_TIME_DESC,
      direction: :NEXT,
      page_token: nil,
      page_size: @page_size
    }

    WQ.list_keyset(params, keyset_params)
  end

  defp keyset_query(git_ref_types) do
    [query] =
      capture_queries(fn -> {:ok, _} = list(UUID.uuid4(), git_ref_types) end)
      |> Enum.filter(&String.contains?(&1.sql, ~s("pipeline_requests")))

    query
  end

  defp seed(project_id, counts) do
    Enum.each(counts, fn {type, count} -> insert_requests(project_id, to_string(type), count) end)
    insert_requests(UUID.uuid4(), "pr", 5)
  end

  defp insert_requests(project_id, git_ref_type, count) do
    Repo.query!(
      """
      INSERT INTO pipeline_requests
        (id, definition, request_args, source_args, request_token, top_level,
         initial_request, wf_id, inserted_at, updated_at)
      SELECT md5(random()::text || g)::uuid, '{}',
             jsonb_build_object('project_id', $1::text,
                                'branch_name', $3::text || g, 'organization_id', 'org'),
             jsonb_build_object('git_ref_type', $2::text),
             md5(random()::text || g), true, true, md5(random()::text || g),
             now() - g * interval '1 minute', now()
      FROM generate_series(1, $4::int) g
      """,
      [project_id, git_ref_type, branch_prefix(git_ref_type), count]
    )
  end

  defp branch_prefix("pr"), do: "pull-request-"
  defp branch_prefix("tag"), do: "refs/tags/v"
  defp branch_prefix("branch"), do: "feature-"

  defp in_rolled_back_tx(fun) do
    {:error, {:result, result}} = Repo.transaction(fn -> Repo.rollback({:result, fun.()}) end)
    result
  end

  defp capture_queries(fun) do
    test_pid = self()
    handler = "keyset-git-ref-type-index-test-#{System.unique_integer()}"

    :telemetry.attach(
      handler,
      @telemetry_event,
      fn _event, _measurements, meta, _ ->
        if self() == test_pid, do: send(test_pid, {:query, meta.query, meta.params})
      end,
      nil
    )

    try do
      fun.()
    after
      :telemetry.detach(handler)
    end

    collect_queries([])
  end

  defp collect_queries(acc) do
    receive do
      {:query, sql, params} -> collect_queries([%{sql: sql, params: params} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp index_def(name) do
    %{rows: [[indexdef]]} =
      Repo.query!("SELECT indexdef FROM pg_indexes WHERE indexname = $1", [name])

    indexdef
  end

  defp valid?(name) do
    %{rows: [[valid]]} =
      Repo.query!(
        """
        SELECT i.indisvalid FROM pg_index i
        JOIN pg_class c ON c.oid = i.indexrelid
        WHERE c.relname = $1
        """,
        [name]
      )

    valid
  end
end
