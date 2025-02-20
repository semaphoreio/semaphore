defmodule Gofer.DeploymentTrigger.Model.DeploymentTriggerQueries do
  @moduledoc false

  alias Gofer.DeploymentTrigger.Model.DeploymentTrigger
  alias Gofer.TargetTrigger.Model.TargetTrigger
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.Switch

  import Ecto.Query
  require Ecto.Query
  alias Gofer.EctoRepo

  @list_page_limit 10

  def scan_runnable(startup_time, batch_no, batch_size) do
    EctoRepo.all(
      from(d in DeploymentTrigger,
        where: d.state in [:INITIALIZING, :TRIGGERING, :STARTING],
        where: d.updated_at < ^startup_time,
        order_by: d.updated_at,
        limit: ^batch_size,
        offset: ^(batch_no * batch_size)
      )
    )
  end

  def list_by_target_id(target_id) do
    EctoRepo.all(
      from(dt in DeploymentTrigger,
        join: s in Switch,
        on: dt.switch_id == s.id,
        where: dt.deployment_id == ^target_id,
        order_by: [desc: dt.triggered_at],
        limit: @list_page_limit,
        preload: [switch: s]
      )
    )
  end

  def find_by_id(trigger_id) do
    DeploymentTrigger
    |> EctoRepo.get(trigger_id)
    |> case do
      nil -> {:error, :not_found}
      trigger -> {:ok, trigger}
    end
  end

  def find_by_request_token(request_token) do
    DeploymentTrigger
    |> EctoRepo.get_by(request_token: request_token)
    |> case do
      nil -> {:error, :not_found}
      trigger -> {:ok, trigger}
    end
  end

  def find_by_switch_trigger_and_target(switch_trigger_id, target_name) do
    DeploymentTrigger
    |> Ecto.Query.where(switch_trigger_id: ^switch_trigger_id)
    |> Ecto.Query.where(target_name: ^target_name)
    |> Ecto.Query.preload(:deployment)
    |> EctoRepo.one()
    |> case do
      nil -> {:error, :not_found}
      trigger -> {:ok, trigger}
    end
  end

  def create(switch = %Switch{}, deployment = %Deployment{}, switch_trigger_params) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:token, fn _repo, _result ->
      case find_by_request_token(switch_trigger_params["request_token"]) do
        {:ok, deployment_trigger} -> {:error, deployment_trigger}
        {:error, :not_found} -> {:ok, :not_found}
      end
    end)
    |> Ecto.Multi.run(:create, fn _repo, _result ->
      do_create(switch, deployment, switch_trigger_params)
    end)
    |> EctoRepo.transaction()
    |> case do
      {:ok, %{create: created_deployment_trigger}} -> {:ok, created_deployment_trigger}
      {:error, :token, deployment_trigger, _changes} -> {:ok, deployment_trigger}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  defp do_create(switch = %Switch{}, deployment = %Deployment{}, switch_trigger_params) do
    target_name =
      switch_trigger_params["target_names"]
      |> List.wrap()
      |> List.first()

    promotion_parameters =
      switch_trigger_params
      |> Map.get("env_vars_for_target", %{})
      |> Map.get(target_name, [])
      |> Map.new(&{&1["name"], &1["value"]})

    %DeploymentTrigger{}
    |> DeploymentTrigger.changeset(%{
      deployment_id: deployment.id,
      switch_id: switch.id,
      git_ref_type: switch.git_ref_type,
      git_ref_label: switch.label,
      triggered_by: switch_trigger_params["triggered_by"],
      triggered_at: switch_trigger_params["triggered_at"],
      request_token: switch_trigger_params["request_token"],
      switch_trigger_id: switch_trigger_params["id"],
      switch_trigger_params: switch_trigger_params,
      target_name: target_name,
      parameter1: promotion_parameters[deployment.bookmark_parameter1],
      parameter2: promotion_parameters[deployment.bookmark_parameter2],
      parameter3: promotion_parameters[deployment.bookmark_parameter3]
    })
    |> EctoRepo.insert()
  end

  def transition_to(_trigger, :DONE) do
    raise "Use finalize/2 to move trigger to :DONE state and set result"
  end

  def transition_to(trigger = %DeploymentTrigger{}, state) do
    trigger
    |> DeploymentTrigger.changeset(%{state: state})
    |> EctoRepo.update()
  rescue
    error in Ecto.StaleEntryError -> {:error, error}
  end

  def finalize(trigger = %DeploymentTrigger{}, target_trigger = %TargetTrigger{}) do
    trigger
    |> DeploymentTrigger.changeset(%{
      state: :DONE,
      pipeline_id: target_trigger.scheduled_ppl_id,
      scheduled_at: target_trigger.scheduled_at,
      result: target_trigger.processing_result,
      reason: target_trigger.error_response
    })
    |> EctoRepo.update()
  rescue
    error in Ecto.StaleEntryError -> {:error, error}
  end

  def finalize(trigger, result, reason) do
    trigger
    |> DeploymentTrigger.changeset(%{
      state: :DONE,
      result: result,
      reason: reason
    })
    |> EctoRepo.update()
  end
end
