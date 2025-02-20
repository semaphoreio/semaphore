defmodule HooksProcessor.Hooks.Model.HooksQueries do
  @moduledoc """
  Hooks Queries
  Operations on Hooks  type
  """

  import Ecto.Query

  alias HooksProcessor.Hooks.Model.Hooks
  alias HooksProcessor.EctoRepo, as: Repo
  alias LogTee, as: LT

  @doc """
  Insert new hook in DB in processing state
  """
  def insert(params) do
    params
    |> Map.put(:state, "processing")
    |> Map.put(:request, Map.get(params, :webhook))
    |> insert_()
  end

  defp insert_(hook) do
    %Hooks{}
    |> Hooks.changeset(hook)
    |> Repo.insert()
    |> process_response(hook)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  defp process_response(
         {:error, %Ecto.Changeset{errors: [one_hook_received_at_per_repository: _message]}},
         params
       ) do
    {:ok, hook} = get_by_repo_received_at(params.repository_id, params.received_at)

    LT.info(
      params.repository_id,
      "Hook #{hook.id} - Insert skiped - there is already a hook" <>
        " received at the same time from repository"
    )

    {:ok, hook}
  end

  defp process_response({:ok, hook}, _params) do
    LT.info(
      hook.repository_id,
      "Hook #{hook.id} - stored hook received at:" <>
        " #{hook.received_at} from repository"
    )

    {:ok, hook}
  end

  defp process_response({:error, error}, params) do
    LT.info(
      error,
      "Error while storing a hook received at:" <>
        " #{params.received_at} from repository #{params.repository_id}"
    )

    {:error, error}
  end

  @doc """
  Updates hook record in database
  """
  def update_webhook(hook, params, state, result \\ "OK") do
    params =
      params
      |> Map.put(:state, state)
      |> Map.put(:result, result)

    hook
    |> Hooks.changeset(params)
    |> Repo.update()
    |> process_update_response(hook.id)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  defp process_update_response({:ok, hook}, _params) do
    "state: #{hook.state}, result: #{hook.result}"
    |> add_plumber_ids?(hook)
    |> LT.info("Hook #{hook.id} - updated successfully")

    {:ok, hook}
  end

  defp process_update_response({:error, error}, id) do
    LT.warn(error, "Hook #{id} - updated failed with error")

    {:error, error}
  end

  defp add_plumber_ids?(message, hook = %{state: "launching", result: "OK"}) do
    message <> ", wf_id: #{hook.wf_id}, ppl_id: #{hook.ppl_id}"
  end

  defp add_plumber_ids?(message, _hook), do: message

  @doc """
  Retrurns hooks from given provider that are in a given state for longer than
  a given threshold.
  """
  def hooks_stuck_in_processing(provider, threshold, deadline) do
    Hooks
    |> where(provider: ^provider)
    |> where(state: "processing")
    |> where([h], h.inserted_at < from_now(-1 * ^threshold, "millisecond"))
    |> where([h], h.inserted_at > from_now(-1 * ^deadline, "second"))
    |> order_by([h], desc: h.inserted_at)
    |> limit(100)
    |> select([h], struct(h, [:id, :project_id]))
    |> Repo.all()
    |> return_ok_tuple()
  end

  @doc """
  Get a hook with a given id
  """
  def get_by_id(id) do
    Hooks
    |> where(id: ^id)
    |> Repo.one()
    |> return_tuple("Hook with an id: #{id} not found.")
  end

  @doc """
  Get a hook from a given repository that was received at a given timestamp
  """
  def get_by_repo_received_at(repo_id, timestamp) do
    Hooks
    |> where(repository_id: ^repo_id)
    |> where(received_at: ^timestamp)
    |> Repo.one()
    |> return_tuple("Hook from repo: #{repo_id} received at: #{timestamp} not found.")
  end

  # Utility

  defp return_tuple(nil, nil_msg), do: return_error_tuple(nil_msg)
  defp return_tuple(value, _), do: return_ok_tuple(value)

  defp return_ok_tuple(value), do: {:ok, value}

  defp return_error_tuple(value), do: {:error, value}
end
