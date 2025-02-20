defmodule Support.Factories.DeployKey do
  alias Projecthub.Models.DeployKey
  alias Projecthub.Repo

  def create(params \\ %{}) do
    changeset =
      DeployKey.changeset(
        %DeployKey{},
        Map.merge(
          %{
            private_key: "private_key",
            public_key: "public_key",
            deployed: false,
            project_id: Ecto.UUID.generate(),
            created_at: DateTime.utc_now()
          },
          params
        )
      )

    Repo.insert(changeset)
  end
end
