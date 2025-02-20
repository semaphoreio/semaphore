defmodule RepositoryHub.PagedResult do
  alias __MODULE__
  defstruct [:current_page, :page_size, :collection, next_page?: false]

  @type t :: %PagedResult{}
  @type pagination_options :: [current_page: non_neg_integer(), page_size: non_neg_integer()]

  @doc """
    A paged result is a result that is split into multiple pages.

    ## Examples

      iex> new([1, 2, 3, 4])
      %PagedResult{current_page: 1, page_size: 50, next_page?: true, collection: [1, 2, 3, 4]}
      iex> new([])
      %PagedResult{current_page: 1, page_size: 50, next_page?: true, collection: []}
      iex> new([], current_page: 2)
      %PagedResult{current_page: 2, page_size: 50, next_page?: true, collection: []}
      iex> new([1, 2, 3, 4, 5], current_page: 1, page_size: 1)
      %PagedResult{current_page: 1, page_size: 1, next_page?: true, collection: [1, 2, 3, 4, 5]}
  """
  @spec new(Enum.t(), pagination_options()) :: t()
  def new(results \\ [], opts \\ [])

  def new(results, opts) do
    current_page = Keyword.get(opts, :current_page, 1)
    page_size = Keyword.get(opts, :page_size, RepositoryHub.Repo.scrivener_defaults()[:page_size])

    %PagedResult{
      current_page: current_page,
      page_size: page_size,
      collection: results,
      next_page?: true
    }
  end

  def to_scrivener(%PagedResult{} = paged_result) do
    %{
      page: paged_result.current_page,
      page_size: paged_result.page_size
    }
  end

  def next_page(%PagedResult{} = paged_result) do
    paged_result.next_page?
    |> case do
      true ->
        %{
          page: paged_result.current_page + 1,
          page_size: paged_result.page_size
        }

      _ ->
        %{
          page: paged_result.current_page,
          page_size: paged_result.page_size
        }
    end
  end

  @spec from_scrivener(Scrivener.Page.t()) :: PagedResult.t()
  def from_scrivener(scrivener_page) do
    paged_result =
      new(
        scrivener_page.entries,
        current_page: scrivener_page.page_number,
        page_size: scrivener_page.page_size
      )

    if scrivener_page.page_number == scrivener_page.total_pages do
      paged_result
      |> without_next_page()
    else
      paged_result
    end
  end

  defp without_next_page(paged_result) do
    %{paged_result | next_page?: false}
  end
end
