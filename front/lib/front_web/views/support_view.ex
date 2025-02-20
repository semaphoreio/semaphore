defmodule FrontWeb.SupportView do
  use FrontWeb, :view

  def topics_list(plan) do
    if free_plan?(plan) do
      [
        [key: "Choose one main topic…", value: "", disabled: true, selected: true],
        [key: "Feedback", value: "Feedback"],
        [key: "Pricing", value: "Pricing"],
        [key: "Git Service", value: "Git Service"],
        [key: "UX", value: "UX"]
      ]
    else
      [
        [key: "Choose one main topic…", value: "", disabled: true, selected: true],
        [key: "API", value: "API"],
        [key: "Workflows", value: "Workflows"],
        [key: "Dependency Caching", value: "Dependency Caching"],
        [key: "Deployment", value: "Deployment"],
        [key: "Docker", value: "Docker"],
        [key: "Feature Request", value: "Feature Request"],
        [key: "Feedback", value: "Feedback"],
        [key: "Git Service", value: "Git Service"],
        [key: "Organizations & Users", value: "Organizations & Users"],
        [key: "Payment", value: "Payment"],
        [key: "Pre-installed Software", value: "Pre-installed Software"],
        [key: "Pricing", value: "Pricing"],
        [key: "UX", value: "UX"],
        [key: "Other", value: "Other"]
      ]
    end
  end

  def free_plan?(plan) do
    plan == "free"
  end

  def name(user) do
    case String.split(user.name, " ", trim: true) do
      [] -> user.github_login
      [fname, _lname] -> fname
      [name] -> name
      [fname | _tail] -> fname
    end
  end

  def manage_attachment_class(changeset) do
    if changeset && changeset.errors && changeset.errors[:attachment] do
      "f5 black-50 form-control-error"
    else
      "f5 black-50"
    end
  end
end
