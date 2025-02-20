defmodule Gofer.Target.Model.TargetQueries do
  @moduledoc """
  Queries on Target type
  """

  import Ecto.Query

  alias Gofer.Target.Model.Target
  alias Gofer.EctoRepo, as: Repo
  alias LogTee, as: LT
  alias Util.ToTuple

  def insert(params, switch) when is_map(switch) do
    params = params |> Map.merge(%{"switch_id" => Map.get(switch, :id, "")})
    params_for_log = Map.take(params, ["switch_id", "name"])

    try do
      %Target{}
      |> Target.changeset(params)
      |> Repo.insert()
      |> process_response(params_for_log)
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end

  def insert(_params, not_map),
    do:
      {:error,
       "TargetQueries.insert() expects a map as switch parametar, it got: #{inspect(not_map)}"}

  defp process_response(
         {:error, %Ecto.Changeset{errors: [uniqe_target_name_per_switch: _message]}},
         params_for_log
       ) do
    params_for_log
    |> LT.info("TargetQueries.insert() - There is already target for given switch and name: ")

    {:error, {:target_exists, params_for_log}}
  end

  defp process_response({:error, %Ecto.Changeset{errors: [switch_id: message]}}, _) do
    {:error, %{switch: message}}
  end

  defp process_response({:ok, target}, params_for_log) do
    target
    |> LT.info("Persisted target with given data: #{inspect(params_for_log)} ")
    |> ToTuple.ok()
  end

  def get_targets_description_for_switch(switch_id) do
    Target
    |> where(switch_id: ^switch_id)
    |> order_by([t], asc: t.name)
    |> select_target_details()
    |> Repo.all()
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  defp select_target_details(query) do
    query
    |> select(
      [t],
      %{
        name: t.name,
        pipeline_path: t.pipeline_path,
        auto_trigger_on: t.auto_trigger_on,
        parameter_env_vars: t.parameter_env_vars,
        deployment_target: t.deployment_target
      }
    )
  end

  def get_by_id_and_name(switch_id, name) do
    Target
    |> where(switch_id: ^switch_id)
    |> where(name: ^name)
    |> Repo.one()
    |> return_tuple("Target for switch: #{switch_id} with name: #{name} not found")
  rescue
    e -> {:error, e}
  end

  def get_all_targets_for_switch(switch_id) do
    Target
    |> where(switch_id: ^switch_id)
    |> Repo.all()
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _), do: ToTuple.ok(value)
end
