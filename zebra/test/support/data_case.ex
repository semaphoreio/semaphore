defmodule Zebra.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Zebra.LegacyRepo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Zebra.DataCase
      import Mock

      def with_stubbed_http_calls(callback, code \\ 200) do
        with_mock(
          HTTPoison,
          post: fn _, _, _, _ ->
            {
              :ok,
              %HTTPoison.Response{body: nil, headers: nil, status_code: code}
            }
          end
        ) do
          callback.()
        end
      end
    end
  end

  setup _ do
    FunRegistry.start()
    FunRegistry.clear!()

    Cachex.reset(:zebra_cache)

    Mox.stub_with(Support.MockedProvider, Support.StubbedProvider)

    # using truncate strategy instead of sandboxes
    assert {:ok, _} = Ecto.Adapters.SQL.query(Zebra.LegacyRepo, "truncate table jobs cascade;")
    assert {:ok, _} = Ecto.Adapters.SQL.query(Zebra.LegacyRepo, "truncate table builds;")

    assert {:ok, _} =
             Ecto.Adapters.SQL.query(
               Zebra.LegacyRepo,
               "truncate table job_stop_requests cascade;"
             )

    :ok
  end

  @doc """
  A helper that transform changeset errors to a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
