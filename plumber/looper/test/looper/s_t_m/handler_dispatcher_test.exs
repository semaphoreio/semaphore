defmodule Looper.STM.HandlerDispatcherTest do
  use ExUnit.Case

  alias Looper.STM.HandlerDispatcher, as: HD

  setup do
    tr_handler_called?()
    tr_handler_called?()
    scheduling_handler_called?()
    scheduling_handler_called?()
    {:ok, []}
  end

  test "call TR_handler when TR not empty and propagate TR to TR_handler" do
    HD.call("stop", %{}, &tr_handler/2, &scheduling_handler/1)
    assert tr_handler_called?() == "stop"
  end

  test "do not call TR_handler when TR empty" do
    HD.call("", %{}, &tr_handler/2, &scheduling_handler/1)
    assert tr_handler_called?() == nil
  end

  test "call sch_handler when TR empty and propagate item to sch_handler" do
    HD.call("", %{}, &tr_handler/2, &scheduling_handler/1)
    assert scheduling_handler_called?() == %{}
  end

  test "do not call scheduling handler when TR not empty" do
    HD.call("stop", %{}, &tr_handler/2, &scheduling_handler/1)
    assert scheduling_handler_called?() == nil
  end

  test "return sch_handler return value when TR is empty" do
    assert HD.call("", %{}, &tr_handler/2, fn _ -> :foo end) == :foo
  end

  test "return TR_handler return value when TR is not empty" do
    assert HD.call("stop", %{}, fn _, _ -> :foo end , fn _ -> :foo end) == :foo
  end

  test "return sch_handler return value when TR is not empty but TR_handler returns continue" do
    assert HD.call("stop", %{}, fn _, _ -> {:ok, :continue} end, fn _ -> :foo end) == :foo
  end

  def tr_handler(_item, tr),    do: send(self(), {:tr_handler, tr})
  def scheduling_handler(item), do: send(self(), {:scheduling_handler, item})

  def tr_handler_called?(), do: handler_called?(:tr_handler)

  def scheduling_handler_called?(), do: handler_called?(:scheduling_handler)

  def handler_called?(handler) do
    receive do
      {^handler, message} -> message
    after
      0 -> nil
    end
  end
end
