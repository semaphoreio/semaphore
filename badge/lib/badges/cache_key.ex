defmodule Badges.CacheKey do
  require Logger

  def calculate(list) do
    :crypto.hash(:sha256, Enum.join(list))
    |> Base.encode16()
    |> String.downcase()
  end
end
