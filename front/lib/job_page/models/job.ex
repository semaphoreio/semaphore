# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule JobPage.Models.Job do
  alias InternalApi.ServerFarm.Job.Job.{Result, State}

  defstruct [
    :id,
    :name,
    :state,
    :project_id,
    :ppl_id,
    :timer,
    :failure_reason,
    :debug_command,
    :started_at,
    :finished_at,
    :self_hosted
  ]

  def find(id, tracing_headers) do
    case JobPage.Api.Job.fetch(id, tracing_headers) do
      nil -> nil
      x -> construct(x)
    end
  end

  defp construct(raw) do
    %__MODULE__{
      id: raw.id,
      name: raw.name,
      state: state(raw),
      project_id: raw.project_id,
      ppl_id: raw.ppl_id,
      timer: timer(raw),
      started_at: format_date(raw.timeline.started_at),
      finished_at: format_date(raw.timeline.finished_at),
      failure_reason: raw.failure_reason,
      debug_command: debug_command(raw),
      self_hosted: raw.self_hosted
    }
  end

  defp state(raw) do
    cond do
      State.key(raw.state) == :STARTED ->
        "running"

      State.key(raw.state) == :FINISHED and Result.key(raw.result) == :PASSED ->
        "passed"

      State.key(raw.state) == :FINISHED and Result.key(raw.result) == :FAILED ->
        "failed"

      State.key(raw.state) == :FINISHED and Result.key(raw.result) == :STOPPED ->
        "stopped"

      true ->
        "pending"
    end
  end

  def debug_command(raw) do
    if State.key(raw.state) == :FINISHED do
      "sem debug job #{raw.id}"
    else
      "sem attach #{raw.id}"
    end
  end

  defp format_date(time) do
    if time do
      time.seconds
      |> DateTime.from_unix!()
      |> Timex.format!("%FT%T%:z", :strftime)
    else
      ""
    end
  end

  defp timer(raw) do
    case state(raw) do
      x when x in ["passed", "failed", "stopped"] ->
        if raw.timeline.started_at && raw.timeline.finished_at do
          raw.timeline.finished_at.seconds - raw.timeline.started_at.seconds
        else
          0
        end

      "running" ->
        (DateTime.utc_now() |> DateTime.to_unix()) - raw.timeline.started_at.seconds

      _ ->
        0
    end
  end
end
