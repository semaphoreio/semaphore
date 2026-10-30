defmodule Badges.Svg do
  @styles ["semaphore", "shields"]

  def render(state, style) when style in @styles do
    badge_path = Path.expand("assets/badges/#{style}/#{state}.svg")

    case File.read(badge_path) do
      {:ok, badge} -> {:ok, badge}
      _ -> {:error, :badge_not_found}
    end
  end

  def render(_state, _style), do: {:error, :badge_not_found}
end
