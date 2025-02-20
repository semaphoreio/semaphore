defmodule PipelinesAPI.Workflows.WfAuthorize do
  @moduledoc false

  use Plug.Builder
  alias PipelinesAPI.Pipelines.Authorize

  def wf_authorize_create(conn, _opts) do
    Authorize.authorize_create(conn, "opts")
  end

  def wf_authorize_update(conn, _opts) do
    Authorize.authorize_update(conn, "opts")
  end

  def wf_authorize_read(conn, _opts) do
    Authorize.authorize_read(conn, "opts")
  end

  def wf_authorize_read_list(conn, _opts) do
    Authorize.authorize_read_list(conn, "opts")
  end
end
