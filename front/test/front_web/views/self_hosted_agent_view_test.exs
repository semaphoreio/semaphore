defmodule FrontWeb.SelfHostedAgentViewTest do
  use FrontWeb.ConnCase
  alias FrontWeb.SelfHostedAgentView

  describe ".is_latest?/1" do
    assert SelfHostedAgentView.is_latest?("v2.2.13")
    assert SelfHostedAgentView.is_latest?("v2.2.14")
    assert SelfHostedAgentView.is_latest?("v2.2.21")
    assert SelfHostedAgentView.is_latest?("v2.3.0")
    assert SelfHostedAgentView.is_latest?("v3.0.0")
    refute SelfHostedAgentView.is_latest?("v2.2.12")
    refute SelfHostedAgentView.is_latest?("v2.1.13")
    assert SelfHostedAgentView.is_latest?("v2.3.7")
  end
end
