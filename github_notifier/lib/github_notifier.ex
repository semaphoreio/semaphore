defmodule GithubNotifier do
  @doc """
  Returns true if the application is running on-prem environment.
  """
  def on_prem? do
    System.get_env("ON_PREM") == "true"
  end
end
