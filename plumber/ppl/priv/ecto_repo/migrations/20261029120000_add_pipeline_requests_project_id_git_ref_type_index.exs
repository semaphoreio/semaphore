defmodule Ppl.EctoRepo.Migrations.AddPipelineRequestsProjectIdGitRefTypeIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(
        :pipeline_requests,
        [
          "(request_args ->> 'project_id')",
          "(source_args ->> 'git_ref_type')",
          "inserted_at DESC",
          "id DESC"
        ],
        name: :pipeline_requests_project_id_git_ref_type_inserted_at_id,
        concurrently: true,
        where: "initial_request = true"
      )
    )
  end
end
