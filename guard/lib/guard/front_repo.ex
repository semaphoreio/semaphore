defmodule Guard.FrontRepo do
  use Ecto.Repo,
    otp_app: :guard,
    adapter: Ecto.Adapters.Postgres

  defmodule Quota do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "quotas" do
      field(:type, :string)
      field(:value, :integer)
      field(:organization_id, :binary_id)
    end
  end

  defmodule OauthConnection do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "oauth_connections" do
      field(:user_id, :binary_id)
      field(:provider, :string)
      field(:token, :string)
      field(:github_uid, :string)

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end
  end

  defmodule Member do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "members" do
      field(:github_uid, :string)
      field(:github_username, :string)
      field(:repo_host, :string)
      field(:organization_id, :binary_id)
      field(:invite_email, :string)

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    def changeset(member, params) do
      member
      |> cast(params, [
        :github_uid,
        :github_username,
        :repo_host,
        :organization_id,
        :invite_email
      ])
      |> validate_required([:github_uid, :github_username, :repo_host, :organization_id])
      |> unique_constraint(:github_uid, name: :members_organization_repo_host_uid_index)
    end
  end

  defmodule Project do
    use Ecto.Schema
    import Ecto.Query

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "projects" do
      field(:organization_id, :binary_id)
      field(:creator_id, :binary_id)
    end

    def get_org_which_owns_project(project_id) do
      __MODULE__
      |> where([p], p.id == ^project_id)
      |> select([p], p.organization_id)
      |> Guard.FrontRepo.one()
    end

    def find(project_id) do
      case __MODULE__ |> where(id: ^project_id) |> Guard.FrontRepo.one() do
        nil -> {:error, :project_not_found}
        p -> {:ok, p}
      end
    end
  end
end
