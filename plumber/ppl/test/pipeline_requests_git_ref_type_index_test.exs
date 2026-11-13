defmodule Ppl.PipelineRequestsGitRefTypeIndexTest do
  @moduledoc """
  Project-page listings filtered by git ref type rely on the index from
  20261029120000_add_pipeline_requests_project_id_git_ref_type_index.
  """
  use ExUnit.Case

  alias Ppl.EctoRepo, as: Repo

  @index "pipeline_requests_project_id_git_ref_type_inserted_at_id"

  test "index exists, is valid and has the expected definition" do
    indexdef = index_def(@index)

    assert indexdef =~ "ON public.pipeline_requests USING btree"

    assert indexdef =~
             "((request_args ->> 'project_id'::text)), ((source_args ->> 'git_ref_type'::text)), inserted_at DESC, id DESC"

    assert indexdef =~ "WHERE (initial_request = true)"
    assert valid?(@index)
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
