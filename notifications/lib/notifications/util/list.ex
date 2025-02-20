defmodule Notifications.Util.List do
  import Ecto.Query

  alias Notifications.Repo
  alias Notifications.Models.Notification, as: Model

  def query(org_id, page_size, page_token, order) do
    query = Model |> Model.in_org(org_id)
    token = deserialize_token(page_token)

    page =
      case order do
        :BY_NAME_ASC -> by_name(query, page_size, token)
      end

    {:ok, page.entries, serialize_token(page.metadata.after)}
  end

  def by_name(query, page_size, token) do
    query = query |> order_by([n], asc: n.name, asc: n.id)

    Repo.paginate(
      query,
      cursor_fields: [:name, :id],
      limit: page_size,
      after: token
    )
  end

  def serialize_token(token) when is_nil(token), do: ""
  def serialize_token(token), do: token

  def deserialize_token(token) when token == "", do: nil
  def deserialize_token(token), do: token
end
