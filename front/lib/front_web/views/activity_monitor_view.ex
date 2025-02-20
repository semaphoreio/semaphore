defmodule FrontWeb.ActivityMonitorView do
  use FrontWeb, :view

  def format_date(time) do
    {:ok, formatted} = time |> Timex.format("%FT%T%:z", :strftime)

    formatted
  end
end
