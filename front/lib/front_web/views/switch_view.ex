defmodule FrontWeb.SwitchView do
  use FrontWeb, :view

  def timer(trigger_event) do
    timer(
      trigger_event.pipeline.state,
      trigger_event.pipeline.result,
      FrontWeb.SharedView.total_seconds(
        trigger_event.pipeline.timeline.running_at,
        trigger_event.pipeline.timeline.done_at
      ),
      FrontWeb.SharedView.total_time(
        trigger_event.pipeline.timeline.running_at,
        trigger_event.pipeline.timeline.done_at
      )
    )
  end

  def timer(:QUEUING, _, _total_seconds, _total_time),
    do: "<span class='f5 code orange'>--:--</span>"

  def timer(:RUNNING, _, total_seconds, total_time),
    do: "<span timer run class='f5 code indigo' seconds='#{total_seconds}'>#{total_time}</span>"

  def timer(:STOPPING, _, total_seconds, total_time),
    do: "<span timer run class='f5 code' seconds='#{total_seconds}'>#{total_time}</span>"

  def timer(:DONE, :PASSED, total_seconds, total_time),
    do: "<span timer class='f5 code green' seconds='#{total_seconds}'>#{total_time}</span>"

  def timer(:DONE, :FAILED, total_seconds, total_time),
    do: "<span timer class='f5 code red' seconds='#{total_seconds}'>#{total_time}</span>"

  def timer(:DONE, :STOPPED, total_seconds, total_time),
    do: "<span timer class='f5 code' seconds='#{total_seconds}'>#{total_time}</span>"

  def timer(:DONE, :CANCELED, total_seconds, total_time),
    do: "<span timer class='f5 code' seconds='#{total_seconds}'>#{total_time}</span>"

  def timer(_, _, _, total_time), do: "<span class='f5 code'>#{total_time}</span>"

  def status_icon(trigger_event) do
    status_icon(trigger_event.pipeline.state, trigger_event.pipeline.result)
  end

  def status_icon(:RUNNING, _), do: "icn-running.svg"
  def status_icon(:STOPPING, _), do: "icn-running.svg"
  def status_icon(:DONE, :PASSED), do: "icn-passed.svg"
  def status_icon(:DONE, :FAILED), do: "icn-failed.svg"
  def status_icon(:DONE, :STOPPED), do: "icn-stopped.svg"
  def status_icon(:DONE, :CANCELED), do: "icn-stopped.svg"
  def status_icon(_, _), do: "icn-enqueued.svg"

  def triggered_at(trigger_event) do
    DateTime.from_unix(trigger_event.triggered_at)
    |> elem(1)
    |> Timex.format("%FT%T%:z", :strftime)
    |> elem(1)
  end
end
