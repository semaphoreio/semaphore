defmodule JobPage.GrpcConfig do
  def endpoint(name) do
    Application.fetch_env!(:front, name)
  end
end
