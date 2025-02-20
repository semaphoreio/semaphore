defmodule TaskApiReferent.Validation.Task do
  @moduledoc """
  Contains validation methods for Tasks
  """

  alias TaskApiReferent.Validation

  @doc "Validates Task's structure."
  def validate(task) when is_map(task) do
    with {:ok, jobs} <- Map.fetch(task, :jobs),
         {:ok, _}    <- Validation.Job.validate_all(jobs)
    do
      {:ok, task}
    else
      {:error, {_, message}} ->
        raise GRPC.RPCError, status: GRPC.Status.invalid_argument, message: message
    end
  end
end
