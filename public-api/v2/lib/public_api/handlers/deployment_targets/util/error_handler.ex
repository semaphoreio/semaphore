defmodule PublicAPI.Handlers.DeploymentTargets.Util.ErrorHandler do
  @moduledoc """
  Contains a function that handles the rescue in the operation handler.
  """

  def handle_error(conn, error, operation) do
    case error do
      %{message: message} ->
        PublicAPI.Util.ToTuple.user_error(%{message: message})
        |> PublicAPI.Util.Response.respond(conn)

      error ->
        require Logger
        Logger.error("Error #{operation} deployment target: #{inspect(error)}")

        PublicAPI.Util.ToTuple.internal_error(%{
          message: "Internal error, please try again later or contact support."
        })
        |> PublicAPI.Util.Response.respond(conn)
    end
  end
end
