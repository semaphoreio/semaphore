defmodule Ppl.EctoRepo.Migrations.PipelineRequestsPrBranchIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists index(
      :pipeline_requests,
      [
        "(request_args ->> 'project_id')",
        "(source_args ->> 'git_ref_type')",
        "(source_args ->> 'branch_name')",
        "inserted_at DESC",
        "id DESC"
      ],
      where: "source_args ->> 'git_ref_type' = 'pr'",
      name: "pipeline_requests_pr_target_branch_index"
    )
    create_if_not_exists index(
      :pipeline_requests,
      [
        "(request_args ->> 'project_id')",
        "(source_args ->> 'git_ref_type')",
        "(source_args ->> 'branch_name')",
        "(request_args ->> 'working_dir')",
        "(request_args ->> 'file_name')",
        "inserted_at DESC",
        "id DESC"
      ],
      where: "source_args ->> 'git_ref_type' = 'pr'",
      name: "pipeline_requests_pr_target_branch_yml_file_index"
    )
    create_if_not_exists index(
      :pipeline_requests,
      [
        "(request_args ->> 'project_id')",
        "(source_args ->> 'git_ref_type')",
        "(source_args ->> 'pr_branch_name')",
        "inserted_at DESC",
        "id DESC"
      ],
      where: "source_args ->> 'git_ref_type' = 'pr'",
      name: "pipeline_requests_pr_head_branch_index"
    )
    create_if_not_exists index(
      :pipeline_requests,
      [
        "(request_args ->> 'project_id')",
        "(source_args ->> 'git_ref_type')",
        "(source_args ->> 'pr_branch_name')",
        "(request_args ->> 'working_dir')",
        "(request_args ->> 'file_name')",
        "inserted_at DESC",
        "id DESC"
      ],
      where: "source_args ->> 'git_ref_type' = 'pr'",
      name: "pipeline_requests_pr_head_branch_yml_file_index"
    )
  end
end
