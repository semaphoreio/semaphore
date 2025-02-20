defmodule TaskApiReferent.Validation.Job do
  @moduledoc """
  Contains validation methods for Jobs
  """

  alias TaskApiReferent.Validation

  @doc "Validates structure of Job List"
  def validate_all(jobs) when is_list(jobs) do
    with {:ok, _} <- empty?(jobs),
         {:ok, _} <- valid?(jobs)
    do
      {:ok, "All Jobs are valid."}
    else
      {:error, msg} ->
        {:error, {:BAD_PARAM, msg}}
    end
  end
  def validate_all(_, _), do: {:error, {:BAD_PARAM, "'jobs' parameter is of invalid type, must be of type List."}}

  # Check if 'jobs' List is empty and return appropriate response we can handle later
  defp empty?(jobs) do
    if Enum.empty?(jobs) do
      {:error, "'jobs' List must have atleast one Job."}
    else
      {:ok, "'jobs' List contains atleast one Job."}
    end
  end

  # Check if each Job within 'jobs' List is valid
  defp valid?(jobs) do
    with result <- Enum.map(jobs, &(validate(&1))),
         false <- Enum.member?(result, :error)
    do
      {:ok, "All Jobs are valid."}
    else
      true -> {:error, "One or more Jobs in the 'jobs' List is invalid."}
    end
  end

  # Validates structure of a single Job
  def validate(job) when is_map(job) do
    with {:ok, commands} <- Map.fetch(job, :commands),
         {:ok, _} <- Validation.Command.validate_all(commands)
    do
      {:ok, "Job is valid."}
    else
      _ -> :error
    end
  end
  def validate(_), do: :error

end
