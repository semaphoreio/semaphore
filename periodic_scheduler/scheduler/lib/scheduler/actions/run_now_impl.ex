defmodule Scheduler.Actions.RunNowImpl do
  @moduledoc """
  Module serves to immediatelly schedule a workflow based on config from a given
  periodic.
  """

  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersQueries
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.Periodics.Model.Periodics
  alias Scheduler.Clients.{ProjecthubClient, RepositoryClient}
  alias Scheduler.Actions
  alias Util.ToTuple

  def run_now(params) do
    with {:ok, periodic} <- get_periodic(params),
         {:ok, params} <- validate_params(periodic, params),
         false <- suspended?(periodic),
         {:ok, _commit} <- verify_revision_exists(periodic, params),
         {:ok, trigger} <- PeriodicsTriggersQueries.insert(periodic, params),
         {:ok, trigger} <- Actions.schedule_wf(periodic, trigger),
         {:ok, response} <- Actions.describe(params) do
      parameter_values = Enum.into(trigger.parameter_values, [], &Map.from_struct/1)
      trigger = trigger |> Map.from_struct() |> Map.put(:parameter_values, parameter_values)
      response |> Map.put(:trigger, trigger) |> ToTuple.ok()
    end
  end

  defp validate_params(%Periodics{branch: nil}, %{branch: ""}),
    do: "You have to provide branch for this task" |> ToTuple.error(:INVALID_ARGUMENT)

  defp validate_params(%Periodics{pipeline_file: nil}, %{pipeline_file: ""}),
    do: "You have to provide pipeline file for this task" |> ToTuple.error(:INVALID_ARGUMENT)

  defp validate_params(
         periodics = %Periodics{parameters: parameters},
         params = %{parameter_values: values}
       ) do
    branch =
      if String.length(params.branch) > 1,
        do: params.branch,
        else: periodics.branch

    pipeline_file =
      if String.length(params.pipeline_file) > 1,
        do: params.pipeline_file,
        else: periodics.pipeline_file

    case merge_values(parameters, values) do
      {:ok, values} ->
        {:ok,
         params
         |> Map.put(:branch, branch)
         |> Map.put(:pipeline_file, pipeline_file)
         |> Map.put(:parameter_values, values)}

      error ->
        error
    end
  end

  def merge_values(parameters, parameter_values) do
    request_values =
      parameter_values
      |> Enum.map(&{&1.name, String.trim(&1.value)})
      |> Enum.filter(&(String.length(elem(&1, 1)) > 0))
      |> Map.new()

    to_error = &("Parameter '#{&1.name}' is required." |> ToTuple.error(:INVALID_ARGUMENT))

    Enum.reduce_while(parameters, {:ok, []}, fn parameter, {:ok, acc_values} ->
      value = Map.get(request_values, parameter.name, parameter.default_value || "")

      case {String.equivalent?(value, ""), parameter.required} do
        {true, true} -> {:halt, to_error.(parameter)}
        {true, false} -> {:cont, {:ok, acc_values}}
        {false, _} -> {:cont, {:ok, acc_values ++ [%{name: parameter.name, value: value}]}}
      end
    end)
  end

  defp suspended?(%{suspended: true}),
    do: "The organization is supended." |> ToTuple.error(:FAILED_PRECONDITION)

  defp suspended?(_periodic), do: false

  defp get_periodic(%{id: id, requester: user})
       when id != "" and user != "" do
    case PeriodicsQueries.get_by_id(id) do
      {:error, _msg} ->
        "Scheduler with id:'#{id}' not found." |> ToTuple.error(:NOT_FOUND)

      response ->
        response
    end
  end

  defp get_periodic(%{id: ""}),
    do: "The 'id' parameter can not be empty string." |> ToTuple.error(:INVALID_ARGUMENT)

  defp get_periodic(%{requester: ""}),
    do: "The 'requester' parameter can not be empty string." |> ToTuple.error(:INVALID_ARGUMENT)

  defp verify_revision_exists(periodic, params) do
    revision_args = [reference: "refs/heads/" <> params.branch, commit_sha: ""]

    with {:ok, repository_id} <- fetch_project_repository_id(periodic.project_id),
         {:ok, commit} <- fetch_branch_revision(repository_id, revision_args) do
      {:ok, commit}
    else
      {:error, {:describe_project, _project_id}} ->
        "Project assigned to periodic was not found." |> ToTuple.error(:FAILED_PRECONDITION)

      {:error, {:describe_revision, _revision_args}} ->
        "Cannot find git reference #{revision_args[:reference]}."
        |> ToTuple.error(:FAILED_PRECONDITION)
    end
  end

  defp fetch_project_repository_id(project_id) do
    case ProjecthubClient.describe(project_id) do
      {:ok, project} -> {:ok, project.spec.repository.id}
      _ -> {:error, {:describe_project, project_id}}
    end
  end

  defp fetch_branch_revision(repository_id, revision_args) do
    case RepositoryClient.describe_revision(repository_id, revision_args) do
      {:ok, commit} -> {:ok, commit}
      _ -> {:error, {:describe_revision, revision_args}}
    end
  end
end
