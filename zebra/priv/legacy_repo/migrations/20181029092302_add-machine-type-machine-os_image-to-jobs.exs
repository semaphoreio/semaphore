defmodule :"Elixir.Zebra.LegacyRepo.Migrations.Add-machine-type-machine-osImage-to-jobs" do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :machine_type, :string
      add :machine_os_image, :string
    end
  end
end
