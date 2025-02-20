defmodule FrontWeb.GetStartedView do
  use FrontWeb, :view

  def json_config(conn, learn) do
    config(conn, learn)
    |> Poison.encode!(escape: :unicode)
  end

  def config(conn, learn) do
    %{
      baseURL: get_started_index_path(conn, :index, []),
      signalUrl: get_started_signal_path(conn, :signal, []),
      learn: learn
    }
  end
end
