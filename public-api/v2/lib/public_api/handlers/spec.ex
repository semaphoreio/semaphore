defmodule PublicAPI.Handlers.Spec do
  @moduledoc false
  use Plug.Builder

  plug(CORSPlug)
  plug(OpenApiSpex.Plug.RenderSpec)
end
