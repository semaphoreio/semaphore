defmodule Front.Pagination do
  @moduledoc false

  #
  # Constructs pagination links based path, current page number and total
  # page count.
  #
  def construct_links(path, current_page, page_count, link_count \\ 5) do
    range = page_range(current_page, page_count, max_link_count: link_count)

    links =
      Enum.map(range, fn index ->
        %{
          title: to_string(index),
          page: to_string(index),
          page_path: "#{path}?page=#{index}",
          active: current_page == index
        }
      end)

    %{
      :on_first_page => current_page == 1,
      :previous_page => current_page - 1,
      :next_page => current_page + 1,
      :first_page => 1,
      :last_page => page_count,
      :previous_page_path => "#{path}?page=#{current_page - 1}",
      :next_page_path => "#{path}?page=#{current_page + 1}",
      :first_page_path => "#{path}?page=1",
      :last_page_path => "#{path}?page=#{page_count}",
      :has_hidden_first_page => !Enum.member?(range, 1),
      :has_hidden_last_page => !Enum.member?(range, page_count),
      :links => links,
      :on_last_page => current_page == page_count,
      :no_pages => page_count == 0,
      :current_page => current_page
    }
  end

  #
  # Parses current page number from Phoenix params
  #
  def page_number(url_params) do
    case url_params do
      %{"page" => number} ->
        case Integer.parse(number) do
          {number, ""} -> number
          _ -> 1
        end

      _ ->
        1
    end
  end

  #
  # Scrivener is not compatible with latest version of phoenix
  # we have to roll our own pagination.
  #
  # This function accepts the current page number, the total page count, and
  # the number of links we want to generate.
  #
  # We want to pivot around the curent page, and return a range with n/2 links
  # on the left and right side of it.
  #
  # Example: current_page: 5, page_count: 10, max_link_count: 5
  #
  #   => 3, 4, [5], 6, 7
  #
  # When the current page is hitting the left or right side of the page spectrum,
  # we need to handle the edge cases.
  #
  # Example: current_page: 1, page_count: 10, max_link_count: 5
  #
  #   => [1], 2, 3, 4, 5
  #
  # Example: current_page: 10, page_count: 10, max_link_count: 5
  #
  #   => 6, 7, 8, 9, [10]
  #
  def page_range(current_page, page_count, max_link_count: n) when current_page < div(n, 2) + 1 do
    Range.new(1, min(n, page_count))
  end

  def page_range(current_page, page_count, max_link_count: n)
      when page_count - current_page < div(n, 2) + 1 do
    Range.new(max(1, page_count - n + 1), page_count)
  end

  def page_range(current_page, _page_count, max_link_count: n) do
    Range.new(current_page - div(n, 2), current_page + div(n, 2))
  end
end
