defmodule Dashboardhub.Auth do
  def authorize(:LIST, _user_id, _org_id) do
    {:ok, :authorized}
  end

  def authorize(_action, _user_id, _org_id) do
    {:ok, :authorized}
  end

  def authorize(_action, _dashboard_id, _user_id, _org_id) do
    {:ok, :authorized}
  end
end
