defmodule Front.Models.TestExplorer.FlakyTestDisruption do
  alias __MODULE__

  defstruct [
    :context,
    :hash,
    :timestamp,
    :run_id,
    requester: "",
    workflow_name: "",
    url: ""
  ]

  @type t :: %FlakyTestDisruption{
          context: String.t(),
          hash: String.t(),
          timestamp: String.t(),
          run_id: String.t(),
          requester: String.t(),
          workflow_name: String.t(),
          url: String.t()
        }

  def new(params), do: struct(FlakyTestDisruption, params)

  def from_proto(p) do
    if is_nil(p.timestamp) do
      nil
    else
      timestamp = DateTime.from_unix!(p.timestamp.seconds)

      %FlakyTestDisruption{
        context: p.context,
        hash: p.hash,
        run_id: p.run_id,
        timestamp: timestamp
      }
      |> load_workflow_data()
    end
  end

  def from_json(json) do
    %FlakyTestDisruption{
      context: json["test_context"],
      hash: json["test_hash"],
      timestamp: json["test_timestamp"],
      run_id: json["test_run_id"]
    }
    |> load_workflow_data()
  end

  def load_workflow_data(flaky_test_disruption = %FlakyTestDisruption{}) do
    Front.Models.Job.find(flaky_test_disruption.run_id)
    |> case do
      {:error, _} ->
        flaky_test_disruption

      job ->
        ppl_id = job.ppl_id

        Front.Models.Pipeline.find(ppl_id)
        |> case do
          nil ->
            flaky_test_disruption

          ppl ->
            Front.Models.Workflow.find(ppl.workflow_id)
            |> case do
              nil ->
                flaky_test_disruption

              workflow ->
                %{
                  flaky_test_disruption
                  | requester: git_user_or_empty(ppl),
                    workflow_name: workflow.hook.commit_message,
                    url: "/jobs/#{flaky_test_disruption.run_id}"
                }
            end
        end
    end
  end

  def git_user_or_empty(%{triggerer: %{git_user: git_user}}) when not is_nil(git_user),
    do: git_user

  def git_user_or_empty(_), do: ""
end
