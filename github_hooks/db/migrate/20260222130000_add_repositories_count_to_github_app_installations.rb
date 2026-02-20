class AddRepositoriesCountToGithubAppInstallations < ActiveRecord::Migration[5.1]
  def up
    add_column :github_app_installations, :repositories_count, :integer, null: false, default: 0

    execute <<~SQL
      UPDATE github_app_installations
      SET repositories_count = counts.repositories_count
      FROM (
        SELECT installation_id, COUNT(*)::integer AS repositories_count
        FROM github_app_installation_repositories
        GROUP BY installation_id
      ) counts
      WHERE github_app_installations.installation_id = counts.installation_id
    SQL

    add_index :github_app_installations, :repositories_count
  end

  def down
    remove_index :github_app_installations, :repositories_count
    remove_column :github_app_installations, :repositories_count
  end
end
