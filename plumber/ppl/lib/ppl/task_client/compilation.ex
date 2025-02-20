defmodule Ppl.TaskClient.Compilation do
  @moduledoc """
  Handles all actions on Zebra that are connected with compliation tasks
  """
  alias Ppl.PplSubInits.STMHandler.Compilation.Definition
  alias Util.ToTuple

  def start(ppl_req, pfcs, settings) do
    with mix_env <- Application.get_env(:ppl, :environment),
         {:ok, definition} <- Definition.form_definition(ppl_req, pfcs, settings, mix_env),
         {:ok, task_params} <- form_task_params(definition, ppl_req),
         {:ok, result} <- Ppl.TaskClient.schedule(task_params),
         do: handle_schedule_result(result)
  end

  defp form_task_params(task_definition, ppl_req) do
    [
      task_definition,
      %{
        "wf_id" => ppl_req.wf_id,
        "ppl_id" => ppl_req.id,
        # ppl_id can be used here because there is only one compile task per pipeline
        "request_token" => ppl_req.id,
        "project_id" => ppl_req.request_args |> Map.get("project_id", ""),
        "org_id" => ppl_req.request_args |> Map.get("organization_id", ""),
        "deployment_target_id" => ppl_req.request_args |> Map.get("deployment_target_id", ""),
        "hook_id" => ppl_req.request_args |> Map.get("hook_id", ""),
        # this is currently needed for evaluating When expressions in job priority settings
        # it can be removed once that code is removed
        "ppl_args" => ppl_req.request_args |> Map.merge(ppl_req.source_args || %{})
      },
      Ppl.TaskClient.task_api_url()
    ]
    |> ToTuple.ok()
  end

  defp handle_schedule_result({:ok, task}), do: {:ok, task.id}
  defp handle_schedule_result(error = {:error, _error}), do: error
  defp handle_schedule_result(error), do: {:error, error}
end
