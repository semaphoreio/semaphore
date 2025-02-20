defmodule Ppl.Actions.DeleteImpl do
  @moduledoc """
  Module which implements Delete pipeline action
  """

  alias Ppl.DeleteRequests.Model.DeleteRequestsQueries

  def delete({:ok, params}) do
    case DeleteRequestsQueries.insert(params) do
      {:ok, _dr} ->
        {:ok, "Pipelines from given project are scheduled for deletion."}
      {:error, _e} = error -> error
      error -> {:error, error}
    end
  end
end
