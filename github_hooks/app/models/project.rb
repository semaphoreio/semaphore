class Project < ActiveRecord::Base
  MAX_DESCRIPTION_LENGTH = 255

  ACCESSIBLE_ATTRIBUTES = [:name, :description, :website,
                           :repository_attributes, :command_queue_attributes,
                           :webhooks_attributes, :branches_attributes,
                           :disable_new_build_reports]

  belongs_to :organization
  belongs_to :creator, :class_name => "User", :foreign_key => :creator_id

  has_many :branches, :autosave => true, :inverse_of => :project
  has_many :workflows
  has_one :repository, :dependent => :destroy, :autosave => true, :inverse_of => :project

  accepts_nested_attributes_for :branches
  accepts_nested_attributes_for :repository

  validates_presence_of :name, :organization, :creator
  validates :name, :format => { :with => /\A[\w\-\.]+\z/,
                                :message => "can have only alphanumeric characters, underscore and dash." }

  validates :name, :uniqueness => { :scope => :organization }

  scope :by_name, -> { order("name ASC") }

  scope :with_repos, ->(options) { includes(:repository).where(:repositories => { :private => options[:private] }).references(:repository) }
  scope :with_public_repos, -> { includes(:repository).where("repositories.private = false").references(:repositories) }
  scope :with_private_repos, -> { includes(:repository).where("repositories.private = true").references(:repositories) }

  scope :by_creator, ->(user) { where(:creator_id => user.id) }

  def self.publish_updated(project)
    msg_klass = InternalApi::Projecthub::ProjectUpdated
    event = msg_klass.new(
      :project_id => project.id,
      :org_id => project.organization_id,
      :timestamp => ::Google::Protobuf::Timestamp.new(:seconds => project.updated_at.to_i)
    )
    message = msg_klass.encode(event)
    options = {
      :exchange => "project_exchange",
      :routing_key => "updated",
      :url => App.amqp_url
    }

    Tackle.publish(message, options)
  end

  def public_repo?
    !private_repo?
  end

  def find_branch(name)
    branches.find_by_name(name)
  end

  def repo_owner_and_name
    if (repository.owner.blank? || repository.name.blank?) && repository.url.present? # rare but possible
      repository.url.split(":").second.try(:gsub, ".git", "")
    else
      "#{repository.owner}/#{repository.name}"
    end
  end

  def repo_name
    repository.name
  end

  def repo_owner
    repository.owner
  end

  def repo_host
    repository.provider
  end

  def repo_host_account
    creator.repo_host_account(repository.provider)
  end

  def github_repository?
    repo_host == ::Repository::GITHUB_PROVIDER
  end

  def bitbucket_repository?
    repo_host == ::Repository::BITBUCKET_PROVIDER
  end

  def whitelist_branches
    (repository.whitelist.presence || {}).fetch("branches", [])
  end

  def whitelist_tags
    (repository.whitelist.presence || {}).fetch("tags", [])
  end

  def enforce_whitelist?
    organization.enforce_whitelist?
  end
end
