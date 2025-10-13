defmodule FrontTest do
  use ExUnit.Case, async: false

  setup do
    original = Application.get_env(:front, :edition)

    on_exit(fn ->
      Application.put_env(:front, :edition, original)
    end)

    :ok
  end

  test "edition helpers recognise ce" do
    Application.put_env(:front, :edition, "ce")

    assert Front.ce?()
    refute Front.ee?()
    refute Front.onprem?()
    assert Front.os?()
    refute Front.saas?()
  end

  test "edition helpers recognise ee" do
    Application.put_env(:front, :edition, "ee")

    refute Front.ce?()
    assert Front.ee?()
    refute Front.onprem?()
    assert Front.os?()
    refute Front.saas?()
  end

  test "edition helpers recognise onprem" do
    Application.put_env(:front, :edition, "onprem")

    refute Front.ce?()
    refute Front.ee?()
    assert Front.onprem?()
    refute Front.os?()
    refute Front.saas?()
  end

  test "edition helpers treat other values as saas" do
    Application.put_env(:front, :edition, "saas")

    refute Front.ce?()
    refute Front.ee?()
    refute Front.onprem?()
    refute Front.os?()
    assert Front.saas?()
  end
end
