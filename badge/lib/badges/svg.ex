defmodule Badges.Svg do
  def render(state, style) do
    badge_path = Path.expand("assets/badges/#{style}/#{state}.svg")

    case File.read(badge_path) do
      {:ok, badge} -> {:ok, badge}
      _ -> {:error, :badge_not_found}
    end
  end
end
