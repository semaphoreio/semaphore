defmodule Guard.TemplateRenderer do
  require EEx
  require Logger

  @templates_path "templates/"

  def render_template(assigns, template) do
    {:ok, template} = File.read(@templates_path <> template <> ".eex")

    EEx.eval_string(template, assigns)
  end
end
