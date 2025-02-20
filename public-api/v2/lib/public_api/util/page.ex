defmodule PublicAPI.Util.Page do
  @moduledoc """
  A `PublicAPI.Util.Page` has 4 fields that can be accessed:
  `page_size`, `next_page_token` and `prev_page_token` for token pagination. The `entries` field is a list of entries on the current page.
  Fields `entries` and `page_size` are mandatory.


      page = MyApp.Module.paginate(params)

      page.entries
      page.page_size
      page.next_page_token
      page.prev_page_token
  """

  defstruct [
    :next_page_token,
    :prev_page_token,
    :page_size,
    with_direction: false,
    prev_page_dir: "PREVIOUS",
    next_page_dir: "NEXT",
    entries: []
  ]

  @type t :: %__MODULE__{
          entries: list(),
          page_size: integer(),
          next_page_token: String.t(),
          with_direction: boolean(),
          prev_page_dir: String.t(),
          next_page_dir: String.t(),
          prev_page_token: String.t()
        }
  @type t(entry) :: %__MODULE__{
          entries: list(entry),
          page_size: integer(),
          with_direction: boolean(),
          prev_page_dir: String.t(),
          next_page_dir: String.t(),
          next_page_token: String.t(),
          prev_page_token: String.t()
        }

  defimpl Enumerable do
    @spec count(PublicAPI.Util.Page.t()) :: {:error, Enumerable.PublicAPI.Util.Page}
    def count(_page), do: {:error, __MODULE__}

    @spec member?(PublicAPI.Util.Page.t(), term) :: {:error, Enumerable.PublicAPI.Util.Page}
    def member?(_page, _value), do: {:error, __MODULE__}

    @spec reduce(PublicAPI.Util.Page.t(), Enumerable.acc(), Enumerable.reducer()) ::
            Enumerable.result()
    def reduce(%PublicAPI.Util.Page{entries: entries}, acc, fun) do
      Enumerable.reduce(entries, acc, fun)
    end

    @spec slice(PublicAPI.Util.Page.t()) :: {:error, Enumerable.PublicAPI.Util.Page}
    def slice(_page), do: {:error, __MODULE__}
  end

  defimpl Collectable do
    @spec into(PublicAPI.Util.Page.t()) ::
            {term, (term, Collectable.command() -> PublicAPI.Util.Page.t() | term)}
    def into(original) do
      original_entries = original.entries
      impl = Collectable.impl_for(original_entries)
      {_, entries_fun} = impl.into(original_entries)

      fun = fn page, command ->
        %{page | entries: entries_fun.(page.entries, command)}
      end

      {original, fun}
    end
  end
end
