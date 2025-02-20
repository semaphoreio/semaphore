defmodule Rbac.Models.Project do
  defstruct [:id, :name, :owner_id, :repository, :org_id, :integration_type, :state]

  @spec find(String.t()) :: Rbac.Models.Project | nil
  def find(id) do
    case Rbac.Api.Project.fetch(id) do
      nil -> {:error, :project_not_found}
      project -> {:ok, construct(project)}
    end
  end

  def project_being_initialized?(project_id) do
    init_state = :INITIALIZING

    case find(project_id) do
      {:ok, project} -> project.state == init_state
      {:error, _} -> false
    end
  end

  defp construct(raw) do
    %__MODULE__{
      id: raw.project.metadata.id,
      name: raw.project.metadata.name,
      owner_id: raw.project.metadata.owner_id,
      org_id: raw.project.metadata.org_id,
      repository: %{
        id: raw.project.spec.repository.id,
        full_name:
          Enum.join([raw.project.spec.repository.owner, raw.project.spec.repository.name], "/"),
        provider: Rbac.RepoUrl.map_provider(raw.project.spec.repository.url)
      },
      state: raw.project.status.state,
      integration_type: map_integration_type(raw.project.spec.repository.integration_type)
    }
  end

  defp map_integration_type(type) do
    type
    |> Atom.to_string()
    |> String.downcase()
  end
end
