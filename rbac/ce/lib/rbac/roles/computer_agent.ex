defmodule Rbac.Roles.ComputerAgent do
  def role do
    %{
      id: "bdf9e1f2-5818-439e-84b2-16fcd848eaf8",
      name: "Computer Agent",
      description:
        "Computer Agents can use Computers in the projects they are given, and nothing else in the organization. Meant for service accounts that run autonomous agents.",
      permissions: [
        "organization.computers.view"
      ]
    }
  end
end
