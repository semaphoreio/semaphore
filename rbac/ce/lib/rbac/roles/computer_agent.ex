defmodule Rbac.Roles.ComputerAgent do
  def role do
    %{
      id: "bdf9e1f2-5818-439e-84b2-16fcd848eaf8",
      name: "Computer Agent",
      description:
        "Can use computers in the projects they are given, and nothing else in the organization.",
      permissions: [
        "organization.computers.view"
      ]
    }
  end
end
