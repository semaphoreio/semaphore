defmodule Router.NestedParamsTest do
  use ExUnit.Case

  import Test.PipelinesClient, only: [url: 0]

  test "urlencoded body nested past the limit is rejected" do
    assert {:ok, %{status_code: 400}} = post_urlencoded(nested_param(33))
  end

  test "urlencoded body nested within the limit is parsed" do
    assert {:ok, %{status_code: 404}} = post_urlencoded(nested_param(32))
  end

  defp post_urlencoded(body) do
    HTTPoison.post(url() <> "/health_check/ping", body, [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"x-semaphore-user-id", "user_id"},
      {"x-semaphore-org-id", "org_id"}
    ])
  end

  defp nested_param(depth), do: "a" <> String.duplicate("[a]", depth - 1) <> "=1"
end
