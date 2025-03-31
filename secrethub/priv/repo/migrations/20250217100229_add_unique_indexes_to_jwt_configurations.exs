defmodule Secrethub.Repo.Migrations.AddUniqueIndexesToJwtConfigurations do
  use Ecto.Migration

  def up do
    # Drop any existing duplicate records before adding unique constraints
    execute """
    DELETE FROM jwt_configurations
    WHERE id::text NOT IN (
      SELECT MIN(id::text)
      FROM jwt_configurations
      GROUP BY org_id, project_id
    );
    """

    create_if_not_exists unique_index(:jwt_configurations, [:org_id],
      name: :jwt_configurations_org_unique_index,
      where: "project_id IS NULL"
    )

    create_if_not_exists unique_index(:jwt_configurations, [:org_id, :project_id],
      name: :jwt_configurations_org_project_unique_index,
      where: "project_id IS NOT NULL"
    )

    drop_if_exists index(:jwt_configurations, [:org_id, :project_id])
  end

  def down do
    drop_if_exists index(:jwt_configurations, [:org_id],
      name: :jwt_configurations_org_unique_index
    )

    drop_if_exists index(:jwt_configurations, [:org_id, :project_id],
      name: :jwt_configurations_org_project_unique_index
    )
  end
end
