defmodule Front.ProjectPage.ModelTest do
  use ExUnit.Case

  alias Front.ProjectPage.Model
  alias Front.ProjectPage.Model.LoadParams

  describe "load_from_api" do
    setup do
      Support.FakeServices.stub_responses()
    end

    test "returns data collected from APIs" do
      params =
        struct!(LoadParams,
          project_id: "2e4ca2aa-ab16-4eb7-924d-0d698f7ca555",
          organization_id: "2e4ca2aa-ab16-4eb7-924d-0d698f7ca555",
          page_token: "dae0438b-4645-49a0-8254-19e4ea7b9f89",
          direction: "next",
          user_page?: false,
          ref_types: ["branch"]
        )

      {:ok, _data, :from_api} = Model.load_from_api(params)
    end
  end

  describe "cache_key" do
    test "constructs cache key based on parameters" do
      params =
        struct!(LoadParams,
          project_id: "1",
          organization_id: "2",
          page_token: "4",
          direction: "next",
          user_page?: true,
          ref_types: ["branch", "tag"]
        )

      assert Model.cache_key(params) ==
               "#{Model.cache_prefix()}/#{Model.cache_version()}/project_id=1/ref_types=branchtag/list_mode=latest/"
    end
  end

  describe "invalidate" do
    test "deletes the cache key" do
      params =
        struct!(LoadParams,
          project_id: "1",
          organization_id: "2",
          page_token: "4",
          direction: "next",
          user_page?: true,
          ref_types: ["branch", "tag"]
        )

      cache_key = params |> Model.cache_key()
      Cacheman.put(:front, cache_key, "content")

      assert {:ok, 1} = params |> Model.invalidate()
    end
  end
end
