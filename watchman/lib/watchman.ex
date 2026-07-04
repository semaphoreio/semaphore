defmodule Watchman do
  @moduledoc false

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {Task, :start_link, [fn -> :ok end]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def submit(_name, _value, _type), do: :ok
  def benchmark(_name, fun) when is_function(fun, 0), do: fun.()
  def increment(_name), do: :ok
  def increment(_name, _value), do: :ok
  def timing(_name, _value), do: :ok
  def gauge(_name, _value), do: :ok
  def event(_title, _text), do: :ok
  def service_check(_name, _status), do: :ok
end
