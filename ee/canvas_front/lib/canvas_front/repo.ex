defmodule CanvasFront.Repo do
  use Ecto.Repo,
    otp_app: :canvas_front,
    adapter: Ecto.Adapters.Postgres
end
