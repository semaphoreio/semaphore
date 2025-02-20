defmodule Ppl.DefinitionReviser do
  @moduledoc """
  This module makes all necessary revisons on pipeline definition created by user.
  """

  alias Ppl.DefinitionReviser.{
    BlocksGodfather, BlocksReviser, JobsGodfather, Task2Build,
    TaskFileProperty, ImplicitDependency, WhenValidator,
    MaxTimeLimitChecker, ParallelismValidator, JobMatrixValidator
  }

  def revise_definition(definition, ppl_req) do
    with {:ok, definition} <- WhenValidator.validate(definition),
         {:ok, definition} <- TaskFileProperty.fetch_and_merge(definition, ppl_req),
         {:ok, definition} <- MaxTimeLimitChecker.check_exec_time_limits(definition),
         {:ok, definition} <- Task2Build.rename(definition),
         {:ok, definition} <- BlocksGodfather.name_blocks(definition),
         {:ok, definition} <- JobsGodfather.name_jobs(definition),
         {:ok, definition} <- BlocksReviser.revise_blocks_definition(definition, ppl_req),
         {:ok, definition} <- ParallelismValidator.validate(definition),
         {:ok, definition} <- JobMatrixValidator.validate(definition),
    do: ImplicitDependency.convert_to_explicit(definition)
  end
end
