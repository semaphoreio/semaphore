defmodule Badges.Badge do
  require Logger

  alias Badges.{Cache, Variant}
  alias Badges.Models.{Project, Pipeline}

  def variant(org_id, project_name, branch_name, project_id) do
    case find_project(project_name, project_id, org_id) do
      nil ->
        {:error, :project_not_found}

      project ->
        case find_pipeline(project.id, branch_name, project.pipeline_file) do
          nil -> {:ok, Variant.calculate(nil)}
          :error -> {:ok, Variant.calculate(nil)}
          ppl -> {:ok, Variant.calculate(ppl)}
        end
    end
  end

  defp find_project(name, id, org_id) do
    Cache.fetch!(["project", org_id, name, id], :timer.seconds(60), fn ->
      case Project.find(name, org_id, nil) do
        project = %Project{public: true} -> {:commit, project}
        project = %Project{public: false, id: ^id} -> {:commit, project}
        _ -> {:ignore, nil}
      end
    end)
  end

  defp find_pipeline(project_id, branch_name, pipeline_file) do
    Cache.fetch!(["pipeline", project_id, branch_name, pipeline_file], :timer.seconds(10), fn ->
      case Pipeline.find(project_id, branch_name, pipeline_file) do
        nil -> {:ignore, nil}
        {:error, _error} -> {:ignore, :error}
        pipeline -> {:commit, pipeline}
      end
    end)
  end
end
