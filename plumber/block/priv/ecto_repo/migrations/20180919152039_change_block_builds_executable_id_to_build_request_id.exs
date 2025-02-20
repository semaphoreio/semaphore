defmodule Block.EctoRepo.Migrations.ChangeBlockBuildsExecutableIdToBuildRequestId do
  use Ecto.Migration
  import Ecto.Query
  alias Block.EctoRepo, as: Repo

  def up do
    alter table(:block_builds) do
      add :build_request_id, :uuid
    end

    flush()

    from(bb in "block_builds",
      update: [set: [build_request_id: bb.executable_id]],
      where: is_nil(bb.build_request_id))
    |> Repo.update_all([])

    alter table(:block_builds) do
      remove :executable_id
    end
  end

  def down do
    alter table(:block_builds) do
      add :executable_id, :uuid
    end

    flush()

    from(bb in "block_builds",
      update: [set: [executable_id: bb.build_request_id]],
      where: is_nil(bb.executable_id))
    |> Repo.update_all([])

    alter table(:block_builds) do
      remove :build_request_id
    end
  end
end
