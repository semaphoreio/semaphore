defmodule Block.Ctx do
  @moduledoc """
  Convenient and uniform logging mechanism.
  """

  alias Block.Ctx

  defmacro event(name) do
    quote do
      origin = Ctx.origin(__ENV__)
      ctx |> var!() |> Ctx.event_printer(unquote(name), origin, :info)
    end
  end

  defmacro event(blkbe, name) do
    quote do
      __ENV__ |> Ctx.origin() |> Ctx.event_(unquote(blkbe), unquote(name))
    end
  end

  defmacro warn(name) do
    quote do
      origin = Ctx.origin(__ENV__)
      ctx |> var!() |> Ctx.event_printer(unquote(name), origin, :warn)
    end
  end

  defmacro error(name) do
    quote do
      origin = Ctx.origin(__ENV__)
      ctx |> var!() |> Ctx.event_printer(unquote(name), origin, :error)
    end
  end

  def origin(env) do
    {function, arity} = Map.get(env, :function, {:not_known, 0})
    line = Map.get(env, :line)
    "#{env.module}.#{Atom.to_string(function)}/#{arity}(L#{line})"
  end

  def event_printer(ctx, name, origin, level \\ :info)
  def event_printer(ctx, name, origin, level) when is_map(ctx), do:
    event_printer_(ctx, name, origin, level)
  def event_printer(_ctx, name, origin, level), do:
    event_printer_(%{block_id: "not_available"}, name, origin, level)

  def event_printer_(ctx, name, origin, level \\ :info) do
    ctx |> event_msg(name, origin) |> bare_log(level)
  end

  defmacrop build_msg(msg, field) do
    quote do
      build_msg_(unquote(msg), unquote(field), unquote(Macro.var(field, nil)))
    end
  end

  defp build_msg_(msg, _name, val) when is_nil(val) or val == "", do: msg
  defp build_msg_(msg, name, value), do: [msg | ["#{name}: #{value}, "]]

  defp event_msg(ctx, event, origin) do
    block_id = Map.get(ctx, :block_id) || Map.get(ctx, :id)
    type = get_type(ctx)
    state = Map.get(ctx, :state)
    result = Map.get(ctx, :result)
    recovery_count = Map.get(ctx, :recovery_count)
    []
    |> build_msg(:block_id)
    |> build_msg(:type)
    |> build_msg(:state)
    |> build_msg(:event)
    |> build_msg(:result)
    |> build_msg(:recovery_count)
    |> build_msg(:origin)
  end

  defp get_type(ctx) do
    ctx |> Map.get(:__struct__) |> struct_name()
  end

  defp struct_name(nil), do: ""
  defp struct_name(struct) do
    struct |> Module.split() |> Enum.at(-1)
  end

  defp bare_log(content, level), do: Logger.bare_log(level, content)

  @doc """
  Block event returned by Ecto update
  """
  def event_(_origin, blke = {:ok, []}, _name), do: blke
  def event_(origin, blke = {:ok, [ctx]}, name) do
    event_printer(ctx, name, origin)
    blke
  end
  def event_(origin, blke = {_, [ctx]}, name) do
    event_printer(ctx, name, origin, :error)
    blke
  end

  @doc """
  All Block related events returned by Ecto insert
  """
  def event_(origin, blke = {:ok, ctx}, name) do
    event_printer(ctx, name, origin)
    blke
  end
  def event_(origin, blke, name) do
    failure = "#{name}, context: #{inspect blke}"
    event_printer(nil, failure, origin, :error)
    blke
  end

  def from_block(block) do
    %{block_id: Map.get(block, :id)}
  end

end
