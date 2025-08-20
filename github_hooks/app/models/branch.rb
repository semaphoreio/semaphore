class Branch < ActiveRecord::Base
  self.inheritance_column = "foo"

  belongs_to :project, :touch => true, :inverse_of => :branches

  validates :name, :presence => true, :uniqueness => { :scope => :project_id }
  validates :project, :presence => true

  scope :archived, -> { where.not(:archived_at => nil) }
  scope :not_archived, -> { where(:archived_at => nil) }
  scope :by_name, -> { order("name ASC") }
  scope :by_updated_at, -> { order("updated_at DESC") }
  scope :newest_first, -> { order("created_at DESC") }
  scope :not_archived_first, -> { order("archived_at DESC NULLS FIRST") }

  def self.find_or_create_for_workflow(workflow)
    branch = workflow.project.branches.find_or_create_by(:name => workflow.payload.branch)

    if workflow.payload.pull_request?
      options = {
        :pull_request_number => workflow.payload.pull_request_number,
        :pull_request_name => workflow.payload.pull_request_name,
        :display_name => workflow.payload.pull_request_name,
        :ref_type => "pull-request",
        :used_at => Time.current
      }
    elsif workflow.payload.tag?
      options = {
        :display_name => workflow.payload.tag_name,
        :ref_type => "tag",
        :used_at => Time.current
      }
    else # branch
      options = {
        :display_name => workflow.payload.branch,
        :ref_type => "branch",
        :used_at => Time.current
      }
    end

    branch.update(options)

    branch
  end

  def destroy
    Watchman.benchmark("branch.destroy") { super }
  end

  def archive
    update(:archived_at => Time.current)
  end

  def unarchive
    update(:archived_at => nil)
  end

  def run_regardless_of_whitelist?
    !archived? && !project.enforce_whitelist?
  end

  def archived?
    archived_at.present?
  end

  def pull_request?
    pull_request_number.present?
  end

  def repo_host
    project.repo_host
  end
end
