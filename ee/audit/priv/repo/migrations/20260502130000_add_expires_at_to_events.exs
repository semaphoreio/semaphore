defmodule Audit.Repo.Migrations.AddExpiresAtToEvents do
  use Ecto.Migration

  # ADD COLUMN IF NOT EXISTS locks the table even when the column exists, so the
  # catalog is checked first and an existing column leaves the table untouched.
  def up do
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'events'
          AND column_name = 'expires_at'
      ) THEN
        ALTER TABLE events ADD COLUMN expires_at timestamp(0);
      END IF;
    END
    $$
    """)
  end

  def down do
    alter table(:events) do
      remove :expires_at
    end
  end
end
