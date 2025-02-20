defmodule Zebra.Config do
  def fetch!(namespace, key) do
    {:ok, val} = Application.get_env(:zebra, namespace) |> Keyword.fetch(key)

    val
  end
end
