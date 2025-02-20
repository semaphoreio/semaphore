defmodule Gofer.Deployment.Model.DeploymentQueries do
  @moduledoc """
  Gathers database logic for deployments
  """

  import Ecto.Query
  require Ecto.Query

  alias Gofer.DeploymentTrigger.Model.DeploymentTrigger
  alias Gofer.Switch.Model.Switch

  alias Gofer.Deployment.Model.Deployment.EncryptedSecret
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.EctoRepo

  # Public API (available for MVC)

  def list_by_project(project_id) do
    EctoRepo.all(
      from(deployment in Deployment,
        where: deployment.project_id == ^project_id,
        order_by: [asc: deployment.name]
      )
    )
  end

  def list_by_project_with_last_triggers(project_id) do
    Watchman.benchmark("Gofer.deployments.queries.list_detailed", fn ->
      EctoRepo.all(
        from(deployment in Deployment,
          left_join: trigger in DeploymentTrigger,
          on: trigger.deployment_id == deployment.id,
          left_join: switch in Switch,
          on: trigger.switch_id == switch.id,
          where: deployment.project_id == ^project_id,
          distinct: deployment.id,
          order_by: [asc: deployment.name, desc: trigger.triggered_at],
          select: %{deployment: deployment, switch: switch, last_trigger: trigger}
        )
      )
    end)
  end

  def find_by_id(""), do: {:error, :not_found}

  def find_by_id(id) do
    case EctoRepo.get(Deployment, id) do
      nil -> {:error, :not_found}
      deployment -> {:ok, deployment}
    end
  end

  def find_by_unique_token(unique_token) do
    case EctoRepo.get_by(Deployment, unique_token: unique_token) do
      nil -> {:error, :not_found}
      deployment -> {:ok, deployment}
    end
  end

  def find_by_project_and_name(project_id, name) do
    case EctoRepo.get_by(Deployment, project_id: project_id, name: name) do
      nil -> {:error, :not_found}
      deployment -> {:ok, deployment}
    end
  end

  def create(unique_token, params, secret_params) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:unique, fn _repo, _result ->
      case find_by_unique_token(unique_token) do
        {:ok, deployment} -> {:error, deployment}
        {:error, :not_found} -> {:ok, :not_found}
      end
    end)
    |> Ecto.Multi.run(:create, fn _repo, _result ->
      __MODULE__.create(params, secret_params)
    end)
    |> EctoRepo.transaction()
    |> case do
      {:ok, %{create: created_deployment}} -> {:ok, created_deployment}
      {:error, :unique, deployment, _changes} -> {:error, {:already_done, deployment}}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def create(params, secret_params) when is_map(secret_params) do
    secret = EncryptedSecret.new(:create, secret_params)
    unique_token = Map.get(secret_params, :unique_token)

    %Deployment{}
    |> Deployment.changeset(params)
    |> Deployment.set_as_syncing(unique_token)
    |> Deployment.put_encrypted_secret(secret)
    |> EctoRepo.insert()
  end

  def create(params, :no_secret_params) do
    %Deployment{}
    |> Deployment.changeset(params)
    |> Deployment.set_as_finished(:SUCCESS)
    |> EctoRepo.insert()
  end

  def update(deployment_id, unique_token, params, secret_params) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:unique, fn _repo, _result ->
      case find_by_unique_token(unique_token) do
        {:ok, deployment} -> {:error, deployment}
        {:error, :not_found} -> {:ok, :not_found}
      end
    end)
    |> Ecto.Multi.run(:deployment, fn _repo, _result ->
      find_by_id(deployment_id)
    end)
    |> Ecto.Multi.run(:update, fn _repo, result ->
      __MODULE__.update(result.deployment, params, secret_params)
    end)
    |> EctoRepo.transaction()
    |> case do
      {:ok, %{update: updated_deployment}} -> {:ok, updated_deployment}
      {:error, :unique, deployment, _changes} -> {:error, {:already_done, deployment}}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def update(%Deployment{state: :SYNCING}, _params, _secret_params) do
    {:error, {:invalid_state, :SYNCING}}
  end

  def update(deployment = %Deployment{}, params, secret_params) when is_map(secret_params) do
    secret_request_type = if deployment.secret_id, do: :update, else: :create
    secret = EncryptedSecret.new(secret_request_type, secret_params)
    unique_token = Map.get(secret_params, :unique_token)

    deployment
    |> Deployment.changeset(params)
    |> Deployment.set_as_syncing(unique_token)
    |> Deployment.put_encrypted_secret(secret)
    |> EctoRepo.update()
  end

  def update(deployment = %Deployment{}, params, :no_secret_params) do
    deployment
    |> Deployment.changeset(params)
    |> EctoRepo.update()
  end

  def delete(deployment_id, unique_token, secret_params) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:unique, fn _repo, _result ->
      case find_by_unique_token(unique_token) do
        {:ok, deployment} -> {:error, deployment}
        {:error, :not_found} -> {:ok, :not_found}
      end
    end)
    |> Ecto.Multi.run(:deployment, fn _repo, _result ->
      find_by_id(deployment_id)
    end)
    |> Ecto.Multi.run(:delete, fn _repo, result ->
      __MODULE__.delete(result.deployment, secret_params)
    end)
    |> EctoRepo.transaction()
    |> case do
      {:ok, %{delete: deleted_deployment}} -> {:ok, deleted_deployment}
      {:error, :unique, deployment, _changes} -> {:error, {:already_done, deployment}}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def cordon(%Deployment{state: :SYNCING}, _cordoned?) do
    {:error, {:invalid_state, :SYNCING}}
  end

  def cordon(deployment = %Deployment{}, cordoned?) do
    deployment
    |> Ecto.Changeset.change(%{cordoned: cordoned?})
    |> EctoRepo.update()
  end

  def delete(%Deployment{state: :SYNCING}, _secret_params) do
    {:error, {:invalid_state, :SYNCING}}
  end

  def delete(deployment = %Deployment{secret_id: nil}, _secret_params) do
    prune_permanently(deployment)
  end

  def delete(deployment = %Deployment{}, secret_params) do
    secret = EncryptedSecret.new(:delete, secret_params)
    unique_token = Map.get(secret_params, :unique_token)

    deployment
    |> Deployment.set_as_syncing(unique_token)
    |> Deployment.put_encrypted_secret(secret)
    |> EctoRepo.update()
  end

  # Public API (available for engine)

  def scan_syncing(startup_time, batch_no, batch_size) do
    EctoRepo.all(
      from(d in Deployment,
        where: d.state == :SYNCING,
        where: d.updated_at < ^startup_time,
        order_by: d.updated_at,
        limit: ^batch_size,
        offset: ^(batch_no * batch_size),
        select: d.id
      )
    )
  end

  def pass_syncing(deployment = %Deployment{}, secret) do
    deployment
    |> Deployment.set_as_finished(:SUCCESS)
    |> Deployment.put_secret(secret)
    |> Deployment.put_encrypted_secret(nil)
    |> EctoRepo.update()
  end

  def fail_syncing(deployment = %Deployment{}, reason) do
    %Deployment{encrypted_secret: secret} = deployment
    new_secret = EncryptedSecret.with_error(secret, reason)

    deployment
    |> Deployment.set_as_finished(:FAILURE)
    |> Deployment.put_encrypted_secret(new_secret)
    |> EctoRepo.update()
  end

  def prune_permanently(deployment = %Deployment{}) do
    EctoRepo.delete(deployment)
  end
end
