defmodule Zebra.LegacyRepo.Migrations.AddFailFastStrategyToTasks do
  use Ecto.Migration

  def change do
    alter table(:builds) do
      add :fail_fast_strategy, :string
    end
  end
end
