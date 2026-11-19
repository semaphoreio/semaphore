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

    test "with a trigger filter, always loads from api" do
      params = %{@params | trigger: "git"}

      {:ok, _model, :from_api} = Model.get(params)
      {:ok, _model, :from_api} = Model.get(params)
    end

    test "with an unknown trigger filter, uses the cache" do
      params = %{@params | trigger: "foo"}

      {:ok, _model, :from_api} = Model.get(params)
      {:ok, _model, :from_cache} = Model.get(params)
    end
  end

  describe "triggerers" do
    test "maps each trigger filter to its workflow trigger types" do
      assert Model.triggerers("git") == [:HOOK]
      assert Model.triggerers("tasks") == [:SCHEDULE, :MANUAL_RUN]
      assert Model.triggerers("api") == [:API]
    end

    test "every trigger type belongs to exactly one filter" do
      covered = Enum.flat_map(["git", "tasks", "api"], &Model.triggerers/1)

      all =
        InternalApi.PlumberWF.TriggeredBy.__message_props__().field_props
        |> Map.values()
        |> Enum.map(& &1.name_atom)

      assert Enum.sort(covered) == Enum.sort(all)
    end

    test "with no or an unknown filter => no trigger types" do
      assert Model.triggerers("") == []
      assert Model.triggerers(nil) == []
      assert Model.triggerers("foo") == []
    end
  end
end
