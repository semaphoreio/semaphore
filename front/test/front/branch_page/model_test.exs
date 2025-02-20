defmodule Front.BranchPage.ModelTest do
  use ExUnit.Case
  alias Front.BranchPage.Model

  @params struct!(Model.LoadParams,
            branch_name: "test/branch",
            branch_id: "123",
            project_id: "321",
            organization_id: "1234",
            page_token: "",
            direction: "next"
          )

  setup do
    Cacheman.clear(:front)
    Support.FakeServices.stub_responses()
    :ok
  end

  describe "load_from_api" do
    test "returns branch page model" do
      assert @params |> Model.load_from_api()
    end
  end

  describe "get" do
    test "it gets branch data from api on first call and from cache on succeeding" do
      {:ok, _model, source} = @params |> Model.get()

      assert source == :from_api

      {:ok, _model, source} = @params |> Model.get()

      assert source == :from_cache
    end
  end
end
