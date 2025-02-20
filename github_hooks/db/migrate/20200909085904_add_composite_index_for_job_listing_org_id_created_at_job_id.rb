class AddCompositeIndexForJobListingOrgIdCreatedAtJobId < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  #
  # Adding this index to optimize public job listing.
  #
  # The query has the following format:
  #
  #   SELECT *
  #   FROM jobs
  #   WHERE jobs.organization_id = ?
  #   AND jobs.project_id IN (?, ....)
  #   AND jobs.aasm_state = ANY(ARRAY['finished'])
  #   ORDER BY jobs.created_at DESC, jobs.id DESC LIMIT 31
  #
  def change
    add_index :jobs, [:organization_id, :created_at, :id], order: {created_at: "DESC", id: "DESC"}, algorithm: :concurrently
  end
end
