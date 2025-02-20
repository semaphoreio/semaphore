defmodule Block.EctoRepo.Migrations.AddTaskIdToBlockBuildsTable do
  use Ecto.Migration
  import Ecto.Query
  alias Block.EctoRepo, as: Repo

  def up do
    alter table(:block_builds) do
      add :task_id, :string
    end

    flush()

    from(bb in "block_builds",
      update: [set: [task_id: bb.build_request_id]],
      where: is_nil(bb.build_request_id))
    |> Repo.update_all([])
  end

  def down do
    alter table(:block_builds) do
      remove :task_id
    end
  end
end
