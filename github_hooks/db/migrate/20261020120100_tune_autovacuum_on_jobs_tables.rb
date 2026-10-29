class TuneAutovacuumOnJobsTables < ActiveRecord::Migration[6.1]
  # Fixed dead-tuple thresholds instead of a scale factor, so vacuum frequency
  # does not drift as these tables grow.
  THRESHOLDS = {
    jobs: 500_000,
    job_stop_requests: 50_000,
    workflows: 300_000,
    builds: 200_000
  }.freeze

  # Tables that had autovacuum_vacuum_scale_factor = 0.02 before this migration.
  PREVIOUS_SCALE_FACTOR = %i[jobs job_stop_requests].freeze

  def up
    THRESHOLDS.each do |table, threshold|
      execute "ALTER TABLE #{table} SET (autovacuum_vacuum_scale_factor = 0, autovacuum_vacuum_threshold = #{threshold})"
    end
  end

  def down
    THRESHOLDS.each_key do |table|
      execute "ALTER TABLE #{table} RESET (autovacuum_vacuum_scale_factor, autovacuum_vacuum_threshold)"

      if PREVIOUS_SCALE_FACTOR.include?(table)
        execute "ALTER TABLE #{table} SET (autovacuum_vacuum_scale_factor = 0.02)"
      end
    end
  end
end
