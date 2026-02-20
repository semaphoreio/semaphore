class AddNormalizedSlugIndexToGithubAppInstallationRepositories < ActiveRecord::Migration[5.1]
  def up
    add_index :github_app_installation_repositories, "LOWER(slug)", name: "idx_gh_app_inst_repos_on_lower_slug"
  end

  def down
    remove_index :github_app_installation_repositories, name: "idx_gh_app_inst_repos_on_lower_slug"
  end
end
