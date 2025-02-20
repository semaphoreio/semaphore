defmodule Ppl.Ctx do
  @moduledoc """
  Convenient and uniform logging mechanism.
  """

  alias Ppl.Ctx

  defmacro event(name) do
    quote do
      origin = Ctx.origin(__ENV__)
      ctx |> var!() |> Ctx.event_printer(unquote(name), origin, :info)
    end
  end

  defmacro event(pple, name) do
    quote do
      __ENV__ |> Ctx.origin() |> Ctx.event_(unquote(pple), unquote(name))
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
    event_printer_(%{ppl_id: "not_available"}, name, origin, level)

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
    ppl_id = Map.get(ctx, :ppl_id) || Map.get(ctx, :id)
    type = get_type(ctx)
    block_index = Map.get(ctx, :block_index)
    state = Map.get(ctx, :state)
    result = Map.get(ctx, :result)
    recovery_count = Map.get(ctx, :recovery_count)
    []
    |> build_msg(:ppl_id)
    |> build_msg(:type)
    |> build_msg(:block_index)
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

  # Pipeline event returned by Ecto update
  def event_(_origin, pple = {:ok, []}, _name), do: pple
  def event_(origin, pple = {:ok, [ctx]}, name) do
    event_printer(ctx, name, origin)
    pple
  end
  def event_(origin, pple = {_, [ctx]}, name) do
    event_printer(ctx, name, origin, :error)
    pple
  end

  # Pipeline event returned by Ecto insert
  def event_(origin, pple = {:ok, ctx}, name) do
    event_printer(ctx, name, origin)
    pple
  end
  def event_(origin, pple, name) do
    failure = "#{name}, context: #{inspect pple}"
    event_printer(nil, failure, origin, :error)
    pple
  end

  def from_ppl(ppl) do
    %{ppl_id: Map.get(ppl, :id)}
  end

end
