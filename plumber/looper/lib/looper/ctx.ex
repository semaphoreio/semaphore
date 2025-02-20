defmodule Looper.Ctx do
  @moduledoc """
  Conveniet and uniform logging mechanism.
  """

  alias Looper.Ctx

  defmacro event(name) do
    quote do
      origin = Ctx.origin(__ENV__)
      ctx |> var!() |> Ctx.event_printer(unquote(name), origin, :info)
    end
  end

  defmacro event(event, name) do
    quote do
      __ENV__ |> Ctx.origin() |> Ctx.event_(unquote(event), unquote(name))
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
    ppl_id          = ctx |> Map.get(:ppl_id) |> to_uuid()
    block_id        = ctx |> Map.get(:block_id) |> to_uuid()
    type            = get_type(ctx)
    block_index     = ctx |> Map.get(:block_index)
    state           = ctx |> Map.get(:state)
    result          = ctx |> Map.get(:result)
    result_reason   = ctx |> Map.get(:result_reason)
    recovery_count  = ctx |> Map.get(:recovery_count)
    []
    |> build_msg(:ppl_id)
    |> build_msg(:block_id)
    |> build_msg(:type)
    |> build_msg(:block_index)
    |> build_msg(:state)
    |> build_msg(:result)
    |> build_msg(:result_reason)
    |> build_msg(:event)
    |> build_msg(:recovery_count)
    |> build_msg(:origin)
  end

  defp to_uuid(nil), do: nil
  defp to_uuid(value) do
    if(String.printable?(value), do: value, else: UUID.binary_to_string!(value))
  end

  defp get_type(ctx) do
    ctx |> Map.get(:__struct__) |> struct_name()
  end

  defp struct_name(nil), do: ""
  defp struct_name(struct) do
   struct |> Module.split() |> Enum.at(-1)
  end

  defp bare_log(content, level), do: Logger.bare_log(level, content)

  # Events returned by exit_scheduling
  def event_(origin, event = {:ok, %{exit_transition: ctx}}, name) do
    event_(origin, {:ok, ctx}, name)
    event
  end

  # Events returned by enter_scheduling
  def event_(_origin, event = {:ok, %{select_item: nil}}, _name), do: event
  def event_(origin, event = {:ok, %{select_item: ctx}}, name) do
    event_(origin, {:ok, ctx}, name)
    event
  end

  # Events returned by Ecto update
  def event_(_origin, event = {:ok, []}, _name), do: event
  def event_(origin, event = {:ok, [ctx]}, name) do
    event_printer(ctx, name, origin)
    event
  end
  def event_(origin, event = {_, [ctx]}, name) do
    event_printer(ctx, name, origin, :error)
    event
  end

  # Events returned by Ecto insert
  def event_(origin, event = {:ok, ctx}, name) do
    event_printer(ctx, name, origin)
    event
  end
  def event_(origin, event, name) do
    failure = "#{name}, context: #{inspect event}"
    event_printer(nil, failure, origin, :error)
    event
  end
end
