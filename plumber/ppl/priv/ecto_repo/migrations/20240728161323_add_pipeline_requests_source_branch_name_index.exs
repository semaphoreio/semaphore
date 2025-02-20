defmodule Ppl.EctoRepo.Migrations.AddIndexOnPrBranchNameAndBranchName do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists index(
      :pipeline_requests,
      [
        "(source_args ->> 'git_ref_type')",
        "(source_args ->> 'branch_name')"
      ],
      where: "source_args ->> 'git_ref_type' = 'pr'",
      name: "pipeline_requests_source_args_branch_name",
      concurrently: true
    )

    create_if_not_exists index(
      :pipeline_requests,
      [
        "(source_args ->> 'git_ref_type')",
        "(source_args ->> 'pr_branch_name')"
      ],
      where: "source_args ->> 'git_ref_type' = 'pr'",
      name: "pipeline_requests_source_args_pr_branch_name",
      concurrently: true
    )
  end
end
