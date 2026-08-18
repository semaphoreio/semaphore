defmodule Support.HangingResolver do
  @moduledoc """
  An offline resolver that never returns: it sleeps far past the egress guard's
  lookup timeout. Used to prove that `Notifications.Egress.UrlGuard.verify/1`
  fails closed (`{:error, :unresolvable}`) within bounded time instead of
  stalling the caller when a resolver hangs.
  """

  @doc "Never returns; the guard must time this out and fail closed."
  def resolve(_host) do
    Process.sleep(:infinity)
  end
end
