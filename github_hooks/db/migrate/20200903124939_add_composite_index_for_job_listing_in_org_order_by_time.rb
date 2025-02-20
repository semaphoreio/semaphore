class AddCompositeIndexForJobListingInOrgOrderByTime < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  #
  # Listing jobs in the Public API requires fast access to jobs executed for a
  # given organization.
  #
  # The query uses the combination of org_id and job state to list jobs, and
  # finally orders them by created_at.
  #
  # What we have now:
  #
  #   Currently we have an index for organization_id, and created_at on jobs.
  #   These are separate indexes, and Postgres can't combine them.
  #
  #   1. It either starts to load the created_at index, and manually filtering by
  #      organization_id. This is slow if you haven't executed any job for over a
  #      day.
  #
  #   2. Or, it uses the organization_id index. In this case it needs to
  #      manually sort all the records in the memory, which requires loading lots
  #      of job rows.
  #
  # Our plan:
  #
  #   We are constructing a composite, ordered index.
  #
  #     1. Compositing the index on org_id, created_at, and aasm_state.
  #
  #     2. Ordering the index by created_at DESC. The default index order is ASC.
  #
  #   We are using a concurrent algorithm for introducing the index into the
  #   database. Concurrency makes sure that we will not have a downtime while
  #   this index is created.
  #
  def change
    add_index :jobs, [:organization_id, :created_at], order: {created_at: "DESC"}, algorithm: :concurrently
  end
end
