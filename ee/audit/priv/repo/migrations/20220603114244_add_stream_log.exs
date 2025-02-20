defmodule Audit.Repo.Migrations.AddStreamLog do
  use Ecto.Migration

  def change do
    create table(:streamer_logs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:org_id, :binary_id)
      add(:streamed_at, :utc_datetime)
      add(:errors, :string)
      add(:provider, :integer)

      add(:file_size, :integer)
      add(:file_name, :string)

      add(:first_event_timestamp, :utc_datetime)
      add(:last_event_timestamp, :utc_datetime)
    end
  end
end
