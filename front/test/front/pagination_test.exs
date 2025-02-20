defmodule Front.PaginationTest do
  use FrontWeb.ConnCase

  alias Front.Pagination

  describe "construct_links" do
    test "when on the first page => sets :on_first_page to true" do
      assert Pagination.construct_links("/branches/12", 1, 12).on_first_page
    end

    test "when not on the first page => sets :on_first_page to false" do
      refute Pagination.construct_links("/branches/12", 10, 12).on_first_page
    end

    test "when on the last page => sets :on_last_page to true" do
      assert Pagination.construct_links("/branches/12", 12, 12).on_last_page
    end

    test "when on the last page => sets :on_last_page to false" do
      refute Pagination.construct_links("/branches/12", 10, 12).on_last_page
    end

    test "sets previous page to current_page - 1" do
      assert Pagination.construct_links("/branches/12", 10, 12).previous_page_path ==
               "/branches/12?page=9"
    end

    test "sets next page to current_page + 1" do
      assert Pagination.construct_links("/branches/12", 10, 12).next_page_path ==
               "/branches/12?page=11"
    end

    test "construct link information" do
      assert Pagination.construct_links("/branches/12", 10, 12).links == [
               %{page: "8", title: "8", page_path: "/branches/12?page=8", active: false},
               %{page: "9", title: "9", page_path: "/branches/12?page=9", active: false},
               %{page: "10", title: "10", page_path: "/branches/12?page=10", active: true},
               %{page: "11", title: "11", page_path: "/branches/12?page=11", active: false},
               %{page: "12", title: "12", page_path: "/branches/12?page=12", active: false}
             ]
    end
  end

  describe "page_number" do
    test "there is no page query param => returns 1" do
      assert Pagination.page_number(%{}) == 1
    end

    test "page query param is present => returns the page number from params" do
      assert Pagination.page_number(%{"page" => "12"}) == 12
    end
  end

  describe "page_range" do
    test "returned page numbers are correct" do
      assert Pagination.page_range(1, 30, max_link_count: 5) == 1..5
      assert Pagination.page_range(2, 30, max_link_count: 5) == 1..5
      assert Pagination.page_range(3, 30, max_link_count: 5) == 1..5
      assert Pagination.page_range(1, 3, max_link_count: 5) == 1..3
      assert Pagination.page_range(3, 3, max_link_count: 5) == 1..3
      assert Pagination.page_range(30, 30, max_link_count: 5) == 26..30
    end
  end
end
