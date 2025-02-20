defmodule Rbac.Repo.RbacRefreshProjectAccessRequest do
  @moduledoc """
    This table is needed to support Rbac.Worker.RefreshProjectAccess
  """

  defmodule ProjectRequest do
    use Rbac.Repo.Schema

    @fields ~w(id action provider role_to_be_assigned)a
    @required ~w(id action provider)a

    @primary_key false
    embedded_schema do
      field(:id, :binary_id)
      field(:role_to_be_assigned, :binary_id)
      field(:provider, Ecto.Enum, values: [:github, :bitbucket])
      field(:action, Ecto.Enum, values: [:add, :remove])
    end

    def changeset(projects, params \\ %{}) do
      projects
      |> cast(params, @fields)
      |> validate_required(@required)
    end
  end

  use Rbac.Repo.Schema
  import Ecto.Query, only: [where: 3, first: 2]

  @required ~w(state org_id user_id)a

  schema "rbac_refresh_project_access_requests" do
    field(:state, Ecto.Enum, values: [:pending, :processing, :done])
    field(:org_id, :binary_id)
    belongs_to(:user, Rbac.Repo.Subject)
    embeds_many(:projects, __MODULE__.ProjectRequest, on_replace: :delete)
    timestamps()
  end

  def add_request(org_id, user_id, project_id, action, provider, role_id \\ nil)
      when action in ~w(add remove)a and provider in ~w(github bitbucket)a do
    if action == :add and role_id == nil do
      throw("If action is :add, role_id must be provided")
    end

    find_request =
      __MODULE__
      |> where([r], r.org_id == ^org_id and r.user_id == ^user_id and r.state == :pending)

    case find_request |> Rbac.Repo.one() do
      nil -> create_new_request(org_id, user_id, project_id, action, provider, role_id)
      req -> req |> add_project_to_request(project_id, action, provider, role_id)
    end
  end

  def load_req_for_processing do
    case __MODULE__
         |> where([req], req.state == ^"pending")
         |> first(:inserted_at)
         |> Rbac.Repo.one() do
      nil ->
        nil

      req ->
        {:ok, req} = req |> changeset(%{state: :processing}) |> Rbac.Repo.update()
        req
    end
  end

  def finish_processing(%__MODULE__{} = req) do
    {:ok, _req} = req |> changeset(%{state: :done}) |> Rbac.Repo.update()
  end

  def failed_processing(%__MODULE__{} = req) do
    {:ok, _req} = req |> changeset(%{state: :pending}) |> Rbac.Repo.update()
  end

  defp create_new_request(org_id, user_id, project_id, action, provider, role_id) do
    %__MODULE__{
      state: :pending,
      org_id: org_id,
      user_id: user_id,
      projects: [
        %__MODULE__.ProjectRequest{
          id: project_id,
          action: action,
          provider: provider,
          role_to_be_assigned: role_id
        }
      ]
    }
    |> Rbac.Repo.insert()
  end

  defp add_project_to_request(req, project_id, action, provider, role_id) do
    existing_projects = req.projects |> Enum.map(&Map.from_struct/1)

    params = %{
      projects:
        existing_projects ++
          [%{id: project_id, action: action, provider: provider, role_to_be_assigned: role_id}]
    }

    req |> changeset(params) |> Rbac.Repo.update()
  end

  defp changeset(record, params) do
    record
    |> cast(params, [:state])
    |> cast_embed(:projects)
    |> validate_required(@required)
  end
end
