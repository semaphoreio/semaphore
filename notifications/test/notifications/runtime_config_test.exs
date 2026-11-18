defmodule Notifications.RuntimeConfigTest do
  use ExUnit.Case

  setup do
    previous = System.get_env("WEBHOOK_BLOCK_INTERNAL_ENDPOINTS")

    on_exit(fn ->
      if previous,
        do: System.put_env("WEBHOOK_BLOCK_INTERNAL_ENDPOINTS", previous),
        else: System.delete_env("WEBHOOK_BLOCK_INTERNAL_ENDPOINTS")
    end)
  end

  test "blocks internal endpoints unless WEBHOOK_BLOCK_INTERNAL_ENDPOINTS is \"false\"" do
    for {value, expected} <- [
          {nil, true},
          {"", true},
          {"true", true},
          {"TRUE", true},
          {"1", true},
          {"false", false}
        ] do
      if value,
        do: System.put_env("WEBHOOK_BLOCK_INTERNAL_ENDPOINTS", value),
        else: System.delete_env("WEBHOOK_BLOCK_INTERNAL_ENDPOINTS")

      config = Config.Reader.read!("config/runtime.exs", env: :test)

      assert config[:notifications][:block_internal_endpoints] == expected, inspect(value)
    end
  end
end
