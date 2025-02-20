defmodule Projecthub.Utils do
  def construct_req_meta(conn) do
    InternalApi.Projecthub.RequestMeta.new(
      api_version: conn.assigns.version,
      kind: "Project",
      req_id: conn.assigns.req_id,
      org_id: conn.assigns.org_id,
      user_id: conn.assigns.user_id
    )
  end
end
