defmodule TaskApiReferent.Sys2app do
  @moduledoc """
  Contains sys2app callback.
  Configures Application environment in runtime.
  """

  alias Util.Config

  def callback, do:
    "K8S_NAMESPACE" |> Config.set_watchman_prefix("task-referent")
end
