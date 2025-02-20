defmodule Guard.Repo do
  use Ecto.Repo,
    otp_app: :guard,
    adapter: Ecto.Adapters.Postgres

  defmodule User do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "users" do
      field(:user_id, :binary_id)
      field(:github_uid, :string)
      field(:provider, :string)

      timestamps(type: :naive_datetime_usec)
    end

    def changeset(user, params \\ %{}) do
      user
      |> cast(params, [:user_id, :github_uid, :provider])
      |> validate_required([:user_id, :github_uid, :provider])
      |> unique_constraint(:github_uid, name: :unique_githubber)
    end
  end

  defmodule Collaborator do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "collaborators" do
      field(:project_id, :binary_id)
      field(:github_username, :string)
      field(:github_uid, :string)
      field(:github_email, :string)
      field(:admin, :boolean)
      field(:push, :boolean)
      field(:pull, :boolean)

      timestamps(type: :naive_datetime_usec)
    end

    def changeset(collaborator, params \\ %{}) do
      collaborator
      |> cast(params, [
        :project_id,
        :github_username,
        :github_uid,
        :github_email,
        :admin,
        :push,
        :pull
      ])
      |> validate_required([:project_id, :github_uid, :github_username])
      |> unique_constraint(:github_uid, name: :unique_githubber_in_project)
    end
  end

  defmodule Project do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "projects" do
      field(:project_id, :binary_id)
      field(:repo_name, :string)
      field(:repository_id, :string)
      field(:provider, :string)
      field(:org_id, :binary_id)

      timestamps(type: :naive_datetime_usec)
    end

    def changeset(project, params \\ %{}) do
      project
      |> cast(params, [:project_id, :repo_name, :provider, :org_id, :repository_id])
      |> validate_required([:project_id, :repo_name, :provider, :org_id])
      |> unique_constraint(:project_id)
    end
  end

  defmodule ProjectMember do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "project_members" do
      field(:project_id, :binary_id)
      field(:user_id, :binary_id)
    end

    def changeset(project_member, params \\ %{}) do
      project_member
      |> cast(params, [:project_id, :user_id])
      |> validate_required([:project_id, :user_id])
      |> unique_constraint(:user_id, name: :unique_member_in_project)
    end
  end

  defmodule Suspension do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "suspensions" do
      field(:org_id, :binary_id)

      timestamps(type: :naive_datetime_usec)
    end

    def changeset(role, params \\ %{}) do
      role
      |> cast(params, [:org_id])
      |> validate_required([:org_id])
    end
  end
end
