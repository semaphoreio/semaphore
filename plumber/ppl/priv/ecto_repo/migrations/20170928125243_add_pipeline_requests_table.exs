defmodule Ppl.EctoRepo.Migrations.AddPipelineRequestsTable do

  use Ecto.Migration

  def change do
    create table(:pipeline_requests, primary_key: false) do
      add :id,                  :uuid,        primary_key: true
      add :definition,          :map
      add :request_args,        :map
      add :request_token,       :string
      add :block_count,         :integer,     default: 0
      add :top_level,           :boolean,     default: false
      add :initial_request,     :boolean,     default: false
      add :switch_id,           :string

      timestamps(type: :naive_datetime_usec)
    end

    create unique_index(:pipeline_requests, [:request_token],
                           name: :unique_request_token_for_ppl_requests)
  end
end
