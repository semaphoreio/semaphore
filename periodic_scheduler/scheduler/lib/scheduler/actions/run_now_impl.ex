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
  alias Scheduler.Utils.GitReference
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

  defp validate_params(%Periodics{reference: nil}, %{reference: ""}),
    do: "You have to provide reference for this task" |> ToTuple.error(:INVALID_ARGUMENT)

  defp validate_params(%Periodics{pipeline_file: nil}, %{pipeline_file: ""}),
    do: "You have to provide pipeline file for this task" |> ToTuple.error(:INVALID_ARGUMENT)

  defp validate_params(
         periodics = %Periodics{parameters: parameters},
         params = %{parameter_values: values}
       ) do
    reference =
      if String.length(params.reference) > 1,
        do: params.reference,
        else: periodics.reference

    pipeline_file =
      if String.length(params.pipeline_file) > 1,
        do: params.pipeline_file,
        else: periodics.pipeline_file

    case merge_values(parameters, values) do
      {:ok, values} ->
        {:ok,
         params
         |> Map.put(:reference, reference)
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

    to_required_error =
      &("Parameter '#{&1.name}' is required." |> ToTuple.error(:INVALID_ARGUMENT))

    Enum.reduce_while(parameters, {:ok, []}, fn parameter, {:ok, acc_values} ->
      {value, source} =
        case Map.fetch(request_values, parameter.name) do
          {:ok, submitted} -> {submitted, :submitted}
          :error -> {parameter.default_value || "", :default}
        end

      case {String.equivalent?(value, ""), parameter.required} do
        {true, true} ->
          {:halt, to_required_error.(parameter)}

        {true, false} ->
          {:cont, {:ok, acc_values}}

        {false, _} ->
          case validate_value_format(parameter, value, source) do
            :ok -> {:cont, {:ok, acc_values ++ [%{name: parameter.name, value: value}]}}
            {:error, _} = err -> {:halt, err}
          end
      end
    end)
  end

  defp validate_value_format(parameter, value, source) do
    validate_input_format? = Map.get(parameter, :validate_input_format, false)
    pattern = Map.get(parameter, :regex_pattern)

    if validate_input_format? and is_binary(pattern) and pattern != "" do
      case Scheduler.SafeRegex.match(pattern, value) do
        {:ok, true} ->
          :ok

        {:ok, false} ->
          format_error(parameter, mismatch_message(source))

        {:error, :value_too_long} ->
          format_error(
            parameter,
            "value exceeds maximum length of #{Scheduler.SafeRegex.max_value_length()} bytes"
          )

        {:error, _reason} ->
          format_error(parameter, "value could not be validated against regex_pattern")
      end
    else
      :ok
    end
  end

  defp mismatch_message(:default),
    do:
      "default value does not match required format; provide an explicit value or fix the default"

  defp mismatch_message(_), do: "value does not match required format"

  defp format_error(parameter, message) do
    "Parameter '#{parameter.name}' #{message}." |> ToTuple.error(:INVALID_ARGUMENT)
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
    git_reference = GitReference.normalize(params.reference)

    revision_args = [reference: git_reference, commit_sha: ""]

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
