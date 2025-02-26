defmodule FrontWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common datastructures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import FrontWeb.Router.Helpers

      # The default endpoint for testing
      @endpoint FrontWeb.Endpoint
    end
  end

  setup _tags do
    FunRegistry.clear!()
    Cachex.clear(:front_cache)
    Cachex.clear(:auth_cache)
    Cachex.clear!(:feature_provider_cache)
    Cacheman.clear(:front)
    Support.Stubs.init()

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
