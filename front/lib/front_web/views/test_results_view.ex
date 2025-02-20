defmodule FrontWeb.TestResultsView do
  use FrontWeb, :view

  def encoded_email(organization, user) do
    data =
      %{
        subject: "Test results - beta feedback",
        body:
          Enum.join(
            [
              "By: #{escape_unsafe_string(user.name)}",
              "From: #{escape_unsafe_string(organization.name)}",
              "========================================",
              "",
              "Share your feedback here…"
            ],
            "\n"
          )
      }
      |> URI.encode_query()
      |> String.replace("+", "%20")

    "mailto:feedback@semaphoreci.com?#{data}"
    |> raw()
  end
end
