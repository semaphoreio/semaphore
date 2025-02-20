defmodule Front.Models.ProjectMetrics.InsightsProjectSettings do
  alias InternalApi.Velocity.DescribeProjectSettingsResponse
  alias InternalApi.Velocity.UpdateProjectSettingsResponse

  alias __MODULE__

  defstruct cd_pipeline_file_name: nil,
            cd_branch_name: nil,
            ci_pipeline_file_name: nil,
            ci_branch_name: nil

  @type t :: %__MODULE__{
          cd_pipeline_file_name: String.t(),
          cd_branch_name: String.t(),
          ci_pipeline_file_name: String.t(),
          ci_branch_name: String.t()
        }

  def from_proto(response = %DescribeProjectSettingsResponse{}) do
    %InsightsProjectSettings{
      cd_pipeline_file_name: response.settings.cd_pipeline_file_name,
      cd_branch_name: response.settings.cd_branch_name,
      ci_pipeline_file_name: response.settings.ci_pipeline_file_name,
      ci_branch_name: response.settings.ci_branch_name
    }
  end

  def from_proto(response = %UpdateProjectSettingsResponse{}) do
    %InsightsProjectSettings{
      cd_pipeline_file_name: response.settings.cd_pipeline_file_name,
      cd_branch_name: response.settings.cd_branch_name,
      ci_pipeline_file_name: response.settings.ci_pipeline_file_name,
      ci_branch_name: response.settings.ci_branch_name
    }
  end
end
