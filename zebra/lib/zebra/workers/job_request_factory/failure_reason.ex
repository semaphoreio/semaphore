defmodule Zebra.Workers.JobRequestFactory.FailureReason do
  @moduledoc """
  Builds job failure reasons that fit the failure_reason column.
  """

  # failure_reason is a varchar(255) column, and Postgres counts codepoints, not graphemes
  @max_length 255
  @max_name_length 40

  @doc """
  Shortens a user-chosen name to #{@max_name_length} codepoints, drops invalid UTF-8
  and replaces control characters such as newlines with "?".
  """
  def clip(name) do
    name
    |> take_codepoints(@max_name_length)
    |> String.replace(~r/[[:cntrl:]]/u, "?")
  end

  @doc """
  Joins as many entries as fit after the prefix, ending with "and N more" when some are left out.
  """
  def join(entries, prefix \\ "")

  def join([], prefix), do: take_codepoints(prefix, @max_length)

  def join(entries, prefix) do
    total = length(entries)

    total..1//-1
    |> Enum.map(&render(prefix, Enum.take(entries, &1), total - &1))
    |> Enum.find(&(codepoint_length(&1) <= @max_length))
    |> case do
      nil -> prefix |> render(Enum.take(entries, 1), total - 1) |> take_codepoints(@max_length)
      reason -> reason
    end
  end

  defp render(prefix, entries, 0), do: prefix <> Enum.join(entries, ", ")

  defp render(prefix, entries, remaining),
    do: render(prefix, entries, 0) <> " and #{remaining} more"

  defp take_codepoints(text, count) do
    text
    |> String.codepoints()
    |> Enum.filter(&String.valid?/1)
    |> Enum.take(count)
    |> Enum.join()
  end

  defp codepoint_length(text), do: text |> String.codepoints() |> length()
end
