defmodule Support.Wait do
  @moduledoc """
  Actively wait for some async event to finish.

  Example, post-processing of okta users:

    > Support.Wait.run("Waiting for the user to be processed", fn ->
        OktaUser.reload(user).state == :processed
      end)
  """

  def run(name, f), do: run(name, 10, 100, f)

  def run(name, 0, _delay, _f), do: raise("Timeout: Wating for #{name}")

  def run(name, attempts, delay, f) do
    if f.() do
      :done
    else
      :timer.sleep(delay)
      run(name, attempts - 1, delay, f)
    end
  end
end
