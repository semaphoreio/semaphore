defmodule Ppl.IntegrationCase do
  use ExUnit.CaseTemplate

  @pfc_url_env_name "INTERNAL_API_URL_PFC"
  @user_url_env_name "INTERNAL_API_URL_USER"
  @org_url_env_name "INTERNAL_API_URL_ORGANIZATION"
  @mock_server_port 50_053

  setup_all do
    System.put_env(@pfc_url_env_name, "localhost:#{@mock_server_port}")
    System.put_env(@user_url_env_name, "localhost:#{@mock_server_port}")
    System.put_env(@org_url_env_name, "localhost:#{@mock_server_port}")

    :ok
  end
end
