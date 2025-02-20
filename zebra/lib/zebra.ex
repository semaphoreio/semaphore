defmodule Zebra do
  @moduledoc """
  Zebra keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def on_prem? do
    System.get_env("ON_PREM") == "true"
  end
end
