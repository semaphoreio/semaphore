defmodule FrontWeb.RegistriesView do
  use FrontWeb, :view

  def decorate_date(google_timestamp) do
    google_timestamp.seconds
    |> DateTime.from_unix!()
    |> Timex.format!("%B %-d, %Y, %I:%M%p", :strftime)
  end
end
