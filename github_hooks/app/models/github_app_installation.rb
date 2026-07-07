class GithubAppInstallation < ActiveRecord::Base
  has_many :contributors, :class_name => "GithubAppCollaborator", :inverse_of => :installation, :dependent => :delete_all, :primary_key => :installation_id, :foreign_key => :installation_id

  def self.find_for_repository!(repository_slug)
    where("repositories::text ILIKE ?", repository_like_pattern(repository_slug)).first!
  end

  def self.find_for_repository(repository_slug)
    where("repositories::text ILIKE ?", repository_like_pattern(repository_slug)).first
  end

  def self.find_for_organization!(organization_name)
    where("repositories::text ILIKE ?", organization_like_pattern(organization_name)).first!
  end

  def self.find_for_organization(organization_name)
    where("repositories::text ILIKE ?", organization_like_pattern(organization_name)).first
  end

  def self.with_more_than_repos(limit)
    where("jsonb_array_length(repositories) > ?", limit)
  end

  def self.organization_name(installation)
    repo = installation.repositories.find { |repo| repo.to_s != "" }
    return unless repo

    repo.split("/")[0]
  end

  def self.normalize_slug(slug)
    normalized_slug = slug.to_s.strip.sub(/\A,+/, "")
    return if normalized_slug.blank?

    # Length caps match GitHub (owner <= 39, repo <= 100). Reject "." / ".."
    # segments so a slug can never traverse a GitHub API path built from it
    # (e.g. owner/../installation -> .../repos/installation).
    return unless normalized_slug.match?(%r{\A[A-Za-z0-9_.-]{1,39}/[A-Za-z0-9_.-]{1,100}\z})
    return if normalized_slug.split("/").any? { |segment| [".", ".."].include?(segment) }

    normalized_slug
  end

  def self.canonical_slug(slug)
    slug.to_s.downcase
  end

  # Build case-insensitive LIKE patterns that match a slug as a quoted JSON
  # string inside the `repositories` jsonb array. Values are escaped with
  # sanitize_sql_like (so LIKE metacharacters like "_" and "%" match literally)
  # and passed as bind parameters, preventing SQL injection via slug/org names.
  def self.repository_like_pattern(repository_slug)
    "%\"#{sanitize_sql_like(repository_slug.to_s)}\"%"
  end

  def self.organization_like_pattern(organization_name)
    # Trailing "/%" is an intentional wildcard matching any repo under the org.
    "%\"#{sanitize_sql_like(organization_name.to_s)}/%\"%"
  end

  private_class_method :repository_like_pattern, :organization_like_pattern
end
