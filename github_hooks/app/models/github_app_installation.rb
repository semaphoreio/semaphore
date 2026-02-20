class GithubAppInstallation < ActiveRecord::Base
  has_many :installation_repositories, :class_name => "GithubAppInstallationRepository", :inverse_of => :installation, :dependent => :delete_all, :primary_key => :installation_id, :foreign_key => :installation_id
  has_many :contributors, :class_name => "GithubAppCollaborator", :inverse_of => :installation, :dependent => :delete_all, :primary_key => :installation_id, :foreign_key => :installation_id
  after_save :sync_repositories_to_table

  def self.find_for_repository!(repository_slug)
    normalized_slug = canonical_slug(normalize_slug(repository_slug).to_s)
    joins(:installation_repositories)
      .where("LOWER(github_app_installation_repositories.slug) = ?", normalized_slug)
      .first!
  end

  def self.find_for_repository(repository_slug)
    normalized_slug = canonical_slug(normalize_slug(repository_slug).to_s)
    joins(:installation_repositories)
      .where("LOWER(github_app_installation_repositories.slug) = ?", normalized_slug)
      .first
  end

  def self.find_for_organization!(organization_name)
    prefix = organization_slug_prefix_pattern(organization_name)
    joins(:installation_repositories)
      .where("LOWER(github_app_installation_repositories.slug) LIKE ?", prefix)
      .first!
  end

  def self.find_for_organization(organization_name)
    prefix = organization_slug_prefix_pattern(organization_name)
    joins(:installation_repositories)
      .where("LOWER(github_app_installation_repositories.slug) LIKE ?", prefix)
      .first
  end

  def self.with_more_than_repos(limit)
    joins(:installation_repositories)
      .group("github_app_installations.id")
      .having("COUNT(github_app_installation_repositories.id) > ?", limit)
  end

  def self.organization_name(installation)
    repo = installation.installation_repositories.order(:created_at, :id).first
    return unless repo

    repo.slug.split("/")[0]
  end

  def self.normalize_repositories(repositories)
    Array(repositories).filter_map do |repository|
      slug =
        if repository.is_a?(String)
          normalize_slug(repository)
        else
          normalize_slug(repository["slug"] || repository["full_name"])
        end
      next if slug.blank?

      id = repository.is_a?(String) ? 0 : (repository["id"] || 0).to_i
      { "id" => id, "slug" => slug }
    end
  end

  def self.normalize_slug(slug)
    normalized_slug = slug.to_s.strip.sub(/\A,+/, "")
    return if normalized_slug.blank?
    return unless normalized_slug.match?(%r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z})

    normalized_slug
  end

  def self.canonical_slug(slug)
    slug.to_s.downcase
  end

  def self.organization_slug_prefix_pattern(organization_name)
    "#{ActiveRecord::Base.sanitize_sql_like(organization_name.to_s.downcase)}/%"
  end

  def repositories
    installation_repositories.order(:created_at, :id).map do |repository|
      { "id" => repository.remote_id, "slug" => repository.slug }
    end
  end

  def repositories=(repositories)
    normalized_repositories = self.class.normalize_repositories(repositories)
    @repositories_to_sync = normalized_repositories
    super(normalized_repositories.map { |repository| repository["slug"] })
  end

  def repository_slugs
    installation_repositories.pluck(:slug)
  end

  def replace_repositories!(repositories)
    with_lock do
      replace_repositories_without_lock!(repositories)
    end
  end

  def add_repositories!(repositories)
    normalized_repositories = self.class.normalize_repositories(repositories)
    return if normalized_repositories.empty?

    with_lock do
      repositories_by_slug = current_repositories_by_slug
      normalized_repositories.each do |repository|
        repositories_by_slug[self.class.canonical_slug(repository["slug"])] = repository
      end
      replace_repositories_without_lock!(repositories_by_slug.values)
    end
  end

  def remove_repositories_by_slug!(slugs)
    normalized_slugs = Array(slugs).filter_map { |slug| self.class.normalize_slug(slug) }.map { |slug| self.class.canonical_slug(slug) }
    return if normalized_slugs.empty?

    with_lock do
      repositories_by_slug = current_repositories_by_slug
      normalized_slugs.each do |slug|
        repositories_by_slug.delete(slug)
      end
      replace_repositories_without_lock!(repositories_by_slug.values)
    end
  end

  private

  def replace_repositories_without_lock!(repositories)
    normalized_repositories = self.class.normalize_repositories(repositories)
    repositories_by_slug = normalized_repositories.index_by do |repository|
      self.class.canonical_slug(repository["slug"])
    end
    current_repositories = installation_repositories.index_by do |repository|
      self.class.canonical_slug(repository.slug)
    end

    # rubocop:disable Rails/SkipsModelValidations
    # Keep this write callback-free to avoid triggering sync_repositories_to_table recursively.
    update_columns(:repositories => repositories_by_slug.values.map { |repository| repository["slug"] })
    # rubocop:enable Rails/SkipsModelValidations
    repositories_to_keep = repositories_by_slug.keys.map { |slug| current_repositories[slug]&.id }.compact
    installation_repositories.where.not(:id => repositories_to_keep).delete_all

    repositories_by_slug.each do |slug, repository|
      current_repository = current_repositories[slug]
      if current_repository
        next if current_repository.remote_id.to_i == repository["id"].to_i && current_repository.slug == repository["slug"]

        # rubocop:disable Rails/SkipsModelValidations
        # Update slug and remote_id directly to preserve API-provided casing without callbacks.
        current_repository.update_columns(
          :remote_id => repository["id"],
          :slug => repository["slug"]
        )
        # rubocop:enable Rails/SkipsModelValidations
      else
        installation_repositories.create!(
          :installation_id => installation_id,
          :remote_id => repository["id"],
          :slug => repository["slug"]
        )
      end
    end
  end

  def current_repositories_by_slug
    installation_repositories.each_with_object({}) do |repository, repositories|
      repositories[self.class.canonical_slug(repository.slug)] = {
        "id" => repository.remote_id,
        "slug" => repository.slug
      }
    end
  end

  def sync_repositories_to_table
    return if @repositories_to_sync.nil?

    replace_repositories!(@repositories_to_sync)
    @repositories_to_sync = nil
  end
end
