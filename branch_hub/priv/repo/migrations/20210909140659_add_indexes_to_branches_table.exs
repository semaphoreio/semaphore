defmodule BranchHub.Repo.Migrations.AddIndexesToBranchesTable do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";")
    execute("CREATE EXTENSION IF NOT EXISTS \"btree_gin\";")

    create index("branches", [:project_id, :name], name: :index_branches_on_project_id_and_name, unique: true)
    create index("branches", [:project_id], name: :index_branches_on_project_id)
    create index("branches", [:archived_at], name: :index_branches_on_archived_at)
    create index("branches", ["display_name gin_trgm_ops"], name: :index_branches_on_display_name_gin_trgm_ops, using: "GIN")
    create index("branches", ["project_id", "used_at DESC"], name: :index_branches_on_project_id_and_used_at)
    create index("branches", ["((project_id)::text)", "display_name gin_trgm_ops"], name: :index_branches_on_project_id_and_display_name, using: "GIN")
    create index("branches", ["display_name gin_trgm_ops", "((project_id)::text)"], name: :index_branches_on_display_name_and_project_id, using: "GIN")
  end
end
