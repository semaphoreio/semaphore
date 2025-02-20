defmodule Support.Logger do
  defmacro __using__(_env) do
    quote do
      import Support.Logger, only: [ii: 1]

      Logger.put_module_level(__MODULE__, :all)
    end
  end

  defmacro ii(something) do
    quote do
      require Logger

      unquote(something)
      |> tap(fn something ->
        something
        |> inspect
        |> Logger.debug(inspect: true)
      end)
    end
  end

  def format(level, message, _timestamp, metadata) do
    if metadata[:inspect] do
      inspect_log(level, message, metadata)
    else
      standard_log(level, message, metadata)
    end
  rescue
    e ->
      "#{inspect(e)}\n"
  end

  def standard_log(level, message, metadata) do
    metadata =
      metadata
      |> Keyword.drop([:file, :line, :inspect])

    "[#{level}] #{message} #{display_metadata(metadata)}\n"
  end

  def inspect_log(level, message, metadata) do
    file_location = "#{metadata[:file]}:#{metadata[:line]}"

    metadata =
      metadata
      |> Keyword.drop([:file, :line, :inspect])

    [
      "#{file_location}",
      "#{display_metadata(metadata)}",
      "#{message}\n"
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.map_join("\n", fn line ->
      "[#{level}] #{line}"
    end)
  end

  def display_metadata(metadata) do
    metadata
    |> Enum.reduce("", fn {key, value}, acc ->
      "#{key}=#{value} #{acc}"
    end)
  end
end
