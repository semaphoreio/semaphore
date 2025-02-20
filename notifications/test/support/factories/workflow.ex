defmodule Support.Factories.Workflow do
  def build(project) do
    %InternalApi.PlumberWF.WorkflowDetails{
      :wf_id => Ecto.UUID.generate(),
      :initial_ppl_id => Ecto.UUID.generate(),
      :project_id => project.metadata.id,
      :hook_id => Ecto.UUID.generate(),
      :requester_id => Ecto.UUID.generate(),
      :branch_id => Ecto.UUID.generate(),
      :branch_name => "master",
      :commit_sha => "a8fc9f410fbf3559271b0150b6ebf5447e875ec0",
      :created_at => %Google.Protobuf.Timestamp{
        :seconds => 1,
        :nanos => 7
      }
    }
  end
end
