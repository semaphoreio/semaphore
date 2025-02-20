defmodule Front.WorkflowPage.PipelineStatus.Model do
  @cache_prefix "pipeline_status_model"
  @cache_version "v0"

  # This function is called from Front.PipelineStatus.CacheInvalidator
  def invalidate(pipeline_id) do
    Cacheman.delete(:front, cache_key(pipeline_id))
  end

  # This function is called from FrontWeb.PipelineController.status/2
  def load(pipeline_id) do
    Cacheman.fetch(:front, cache_key(pipeline_id), fn ->
      pipeline_status = load_pipeline_status_from_api(pipeline_id)
      Cacheman.put(:front, cache_key(pipeline_id), pipeline_status)
      {:ok, pipeline_status}
    end)
  end

  # Private

  defp cache_key(pipeline_id) do
    "#{@cache_prefix}/#{@cache_version}/pipeline_id=#{pipeline_id}/"
  end

  defp load_pipeline_status_from_api(pipeline_id) do
    Front.Models.Pipeline.find(pipeline_id) |> pipeline_favicon_status()
  end

  defp pipeline_favicon_status(pipeline),
    do: pipeline_favicon_status(pipeline.state, pipeline.result)

  defp pipeline_favicon_status(:RUNNING, _), do: "running"
  defp pipeline_favicon_status(:STOPPING, _), do: "stopping"
  defp pipeline_favicon_status(:DONE, :PASSED), do: "passed"
  defp pipeline_favicon_status(:DONE, :FAILED), do: "failed"
  defp pipeline_favicon_status(:DONE, :STOPPED), do: "stopped"
  defp pipeline_favicon_status(:DONE, :CANCELED), do: "canceled"
  defp pipeline_favicon_status(_, _), do: "pending"
end
