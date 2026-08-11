defmodule Front.Models.AgentTypeSanitizerTest do
  use Front.TestCase

  alias Front.Models.AgentTypeSanitizer

  describe "sanitize_hosted_agent_types/1" do
    test "filters deprecated linux images and picks a preferred fallback default" do
      hosted_agent_types = %{
        agent_types: [
          %{type: "e1-standard-2", platform: "LINUX", specs: "2 vCPU", os_image: "ubuntu1804"},
          %{type: "e1-standard-2", platform: "LINUX", specs: "2 vCPU", os_image: "ubuntu2204"},
          %{type: "a1-standard-4", platform: "MAC", specs: "4 vCPU", os_image: "macos-xcode13"}
        ],
        default_linux_os_image: "ubuntu2004",
        default_mac_os_image: "macos-xcode13"
      }

      sanitized = AgentTypeSanitizer.sanitize_hosted_agent_types(hosted_agent_types)

      assert sanitized.default_linux_os_image == "ubuntu2204"

      assert Enum.all?(sanitized.agent_types, fn agent_type ->
               not (agent_type.platform == "LINUX" and
                      agent_type.os_image in ["ubuntu1804", "ubuntu2004"])
             end)
    end

    test "sets linux default to empty when there are no linux images left" do
      hosted_agent_types = %{
        agent_types: [
          %{type: "a1-standard-4", platform: "MAC", specs: "4 vCPU", os_image: "macos-xcode13"}
        ],
        default_linux_os_image: "ubuntu2004",
        default_mac_os_image: "macos-xcode13"
      }

      sanitized = AgentTypeSanitizer.sanitize_hosted_agent_types(hosted_agent_types)

      assert sanitized.default_linux_os_image == ""
    end
  end
end
