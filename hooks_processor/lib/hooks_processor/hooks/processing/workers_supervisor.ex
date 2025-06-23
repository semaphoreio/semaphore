defmodule HooksProcessor.Hooks.Processing.WorkersSupervisor do
  @moduledoc """
  Main supervisor for all the worker processes related to webhook procesing.
  It dynamically starts and monitors a worker process for each individual webhook.
  """
  use DynamicSupervisor

  alias HooksProcessor.Hooks.Processing.{
    BitbucketWorker,
    GitlabWorker,
    GitWorker,
    TestWorker
  }

  alias LogTee, as: LT

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 1000)
  end

  def start_worker_for_webhook(id) do
    provider = Application.get_env(:hooks_processor, :webhook_provider)
    spec = provider |> worker_module_spec(id)

    DynamicSupervisor.start_child(__MODULE__, spec)
    |> process_response(id, provider)
  end

  defp worker_module_spec("bitbucket", id), do: {BitbucketWorker, id}
  defp worker_module_spec("gitlab", id), do: {GitlabWorker, id}
  defp worker_module_spec("git", id), do: {GitWorker, id}
  defp worker_module_spec("test", id), do: {TestWorker, id}

  def children do
    DynamicSupervisor.which_children(__MODULE__)
  end

  def count_children do
    DynamicSupervisor.count_children(__MODULE__)
  end

  defp process_response(resp = {:ok, pid}, id, provider) do
    LT.debug(pid, "Hook #{id} - #{provider} worker started")
    resp
  end

  defp process_response({:error, {:already_started, pid}}, id, provider) do
    LT.debug(pid, "Hook #{id} - #{provider} worker already started")
    {:ok, pid}
  end

  defp process_response(error, id, provider) do
    LT.warn(error, "Hook #{id} - error while starting #{provider} worker")
    {:error, error}
  end
end
