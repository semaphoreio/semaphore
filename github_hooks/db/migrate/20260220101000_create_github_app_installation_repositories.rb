class CreateGithubAppInstallationRepositories < ActiveRecord::Migration[5.1]
  class GithubAppInstallation < ActiveRecord::Base
    self.table_name = "github_app_installations"
  end

  class GithubAppInstallationRepository < ActiveRecord::Base
    self.table_name = "github_app_installation_repositories"
  end

  def up
    create_table :github_app_installation_repositories, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.bigint :installation_id, null: false
      t.bigint :remote_id, null: false, default: 0
      t.string :slug, null: false

      t.timestamps null: false
    end

    rows = []
    now = Time.current
    quoted_now = GithubAppInstallationRepository.connection.quote(now)

    GithubAppInstallation.find_each do |installation|
      repositories_by_slug = {}

      Array(installation[:repositories]).each do |repository|
        slug, remote_id = normalize_repository(repository)
        next if slug.blank?

        existing = repositories_by_slug[slug]
        if existing.nil? || existing[:remote_id].to_i.zero?
          repositories_by_slug[slug] = { :remote_id => remote_id, :slug => slug }
        end
      end

      repositories_by_slug.each_value do |repository|
        rows << [
          installation.installation_id.to_i,
          repository[:remote_id].to_i,
          repository[:slug]
        ]

        flush_rows(rows, quoted_now) if rows.size >= 1000
      end
    end

    flush_rows(rows, quoted_now)
    deduplicate_by_slug!
    deduplicate_by_remote_id!

    add_index :github_app_installation_repositories, :installation_id
    add_index :github_app_installation_repositories, :remote_id
    add_index :github_app_installation_repositories, :slug
    add_index :github_app_installation_repositories, :slug, name: "idx_gh_app_inst_repos_on_slug_like", opclass: :varchar_pattern_ops
    add_index :github_app_installation_repositories, :slug, unique: true, name: "idx_gh_app_inst_repos_on_slug_unique"
    add_index :github_app_installation_repositories, :remote_id, unique: true, where: "remote_id > 0", name: "idx_gh_app_inst_repos_on_remote_id_unique"
    add_index :github_app_installation_repositories, [:installation_id, :slug], unique: true, name: "idx_gh_app_inst_repos_on_inst_slug"
    add_index :github_app_installation_repositories, "LOWER(slug)", name: "idx_gh_app_inst_repos_on_lower_slug"
  end

  def down
    drop_table :github_app_installation_repositories
  end

  private

  def normalize_repository(repository)
    slug =
      if repository.is_a?(String)
        normalize_slug(repository)
      else
        normalize_slug(repository["slug"] || repository[:slug] || repository["full_name"] || repository[:full_name])
      end
    return [nil, 0] if slug.blank?

    remote_id = repository.is_a?(String) ? 0 : (repository["id"] || repository[:id] || 0).to_i
    [slug, remote_id]
  end

  def normalize_slug(slug)
    normalized_slug = slug.to_s.strip.sub(/\A,+/, "")
    return if normalized_slug.blank?
    return unless normalized_slug.match?(/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/)

    normalized_slug
  end

  def flush_rows(rows, quoted_now)
    return if rows.empty?

    values = rows.map do |installation_id, remote_id, slug|
      "(uuid_generate_v4(), #{installation_id}, #{remote_id}, #{quote(slug)}, #{quoted_now}, #{quoted_now})"
    end

    execute <<~SQL
      INSERT INTO github_app_installation_repositories
      (id, installation_id, remote_id, slug, created_at, updated_at)
      VALUES #{values.join(", ")}
    SQL

    rows.clear
  end

  def deduplicate_by_slug!
    execute <<~SQL
      DELETE FROM github_app_installation_repositories
      WHERE id IN (
        SELECT id
        FROM (
          SELECT
            id,
            ROW_NUMBER() OVER (
              PARTITION BY slug
              ORDER BY
                CASE WHEN remote_id > 0 THEN 0 ELSE 1 END,
                created_at,
                id
            ) AS row_num
          FROM github_app_installation_repositories
        ) duplicated
        WHERE duplicated.row_num > 1
      )
    SQL
  end

  def deduplicate_by_remote_id!
    execute <<~SQL
      DELETE FROM github_app_installation_repositories
      WHERE id IN (
        SELECT id
        FROM (
          SELECT
            id,
            ROW_NUMBER() OVER (
              PARTITION BY remote_id
              ORDER BY created_at, id
            ) AS row_num
          FROM github_app_installation_repositories
          WHERE remote_id > 0
        ) duplicated
        WHERE duplicated.row_num > 1
      )
    SQL
  end

  def quote(value)
    GithubAppInstallationRepository.connection.quote(value)
  end
end
