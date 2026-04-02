defmodule Ppl.Retention.ApplicationConfigTest do
  use ExUnit.Case, async: false

  alias Ppl.Application, as: App

  setup do
    cleanup_config()
    on_exit(&cleanup_config/0)
    :ok
  end

  describe "retention worker startup" do
    test "workers are not started when config is missing" do
      children = App.children_()
      modules = child_modules(children)

      refute Ppl.Retention.StateAgent in modules
      refute Ppl.Retention.Policy.Worker in modules
      refute Ppl.Retention.Deleter.Worker in modules
    end

    test "all retention workers start when both are enabled" do
      Application.put_env(:ppl, Ppl.Retention.Policy.Worker, enabled: true)
      Application.put_env(:ppl, Ppl.Retention.Deleter.Worker, enabled: true)

      children = App.children_()
      modules = child_modules(children)

      assert Ppl.Retention.StateAgent in modules
      assert Ppl.Retention.Policy.Worker in modules
      assert Ppl.Retention.Deleter.Worker in modules
    end

    test "only policy worker starts when deleter is disabled" do
      Application.put_env(:ppl, Ppl.Retention.Policy.Worker, enabled: true)

      children = App.children_()
      modules = child_modules(children)

      assert Ppl.Retention.StateAgent in modules
      assert Ppl.Retention.Policy.Worker in modules
      refute Ppl.Retention.Deleter.Worker in modules
    end

    test "only deleter worker starts when policy is disabled" do
      Application.put_env(:ppl, Ppl.Retention.Deleter.Worker, enabled: true)

      children = App.children_()
      modules = child_modules(children)

      assert Ppl.Retention.StateAgent in modules
      refute Ppl.Retention.Policy.Worker in modules
      assert Ppl.Retention.Deleter.Worker in modules
    end

    test "old config keys do not enable workers" do
      Application.put_env(:ppl, Ppl.Retention.PolicyConsumer, enabled: true)
      Application.put_env(:ppl, Ppl.Retention.RecordDeleter, enabled: true)

      children = App.children_()
      modules = child_modules(children)

      refute Ppl.Retention.StateAgent in modules
      refute Ppl.Retention.Policy.Worker in modules
      refute Ppl.Retention.Deleter.Worker in modules
    end
  end

  defp child_modules(children) do
    Enum.map(children, fn
      {module, _, _, _, _, _} -> module
      {module, _} -> module
      module when is_atom(module) -> module
      spec -> spec
    end)
  end

  defp cleanup_config do
    Application.delete_env(:ppl, Ppl.Retention.Policy.Worker)
    Application.delete_env(:ppl, Ppl.Retention.Deleter.Worker)
    Application.delete_env(:ppl, Ppl.Retention.PolicyConsumer)
    Application.delete_env(:ppl, Ppl.Retention.RecordDeleter)
  end
end
