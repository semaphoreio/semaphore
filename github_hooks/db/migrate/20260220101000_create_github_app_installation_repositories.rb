class CreateGithubAppInstallationRepositories < ActiveRecord::Migration[5.1]
  class GithubAppInstallation < ActiveRecord::Base
    self.table_name = "github_app_installations"
  end

  def up
    create_table :github_app_installation_repositories, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.bigint :installation_id, null: false
      t.bigint :remote_id, null: false, default: 0
      t.string :slug, null: false

      t.timestamps null: false
    end

    execute <<~SQL
      INSERT INTO github_app_installation_repositories
      (id, installation_id, remote_id, slug, created_at, updated_at)
      SELECT
        uuid_generate_v4(),
        source.installation_id,
        0,
        source.slug,
        NOW(),
        NOW()
      FROM (
        SELECT DISTINCT ON (LOWER(TRIM(repo_slug)))
          i.installation_id,
          TRIM(repo_slug) AS slug,
          ord
        FROM github_app_installations i
        CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(i.repositories, '[]'::jsonb)) WITH ORDINALITY AS repos(repo_slug, ord)
        WHERE TRIM(repo_slug) <> ''
        ORDER BY LOWER(TRIM(repo_slug)), i.id DESC, ord DESC
      ) source
    SQL

    add_index :github_app_installation_repositories, :installation_id
    add_index :github_app_installation_repositories, :slug
    add_index :github_app_installation_repositories, :slug, name: "idx_gh_app_inst_repos_on_slug_like", opclass: :varchar_pattern_ops
    add_index :github_app_installation_repositories, [:installation_id, :slug], unique: true, name: "idx_gh_app_inst_repos_on_inst_slug"
    execute <<~SQL
      CREATE UNIQUE INDEX idx_gh_app_inst_repos_on_lower_slug_unique
      ON github_app_installation_repositories (LOWER(slug))
    SQL
    execute <<~SQL
      CREATE INDEX idx_gh_app_inst_repos_on_lower_slug_like
      ON github_app_installation_repositories (LOWER(slug) varchar_pattern_ops)
    SQL
  end

  def down
    drop_table :github_app_installation_repositories
  end
end
