defmodule HooksReceiver do
  def ee? do
    Application.get_env(:hooks_receiver, :edition) == "ee"
  end
end
