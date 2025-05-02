defmodule CanvasFrontWeb.ErrorHTMLTest do
  use CanvasFrontWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    assert render_to_string(CanvasFrontWeb.ErrorHTML, "404", "html", []) =~
             "404 Page Not Found · Semaphore"
  end

  test "renders 500.html" do
    assert render_to_string(CanvasFrontWeb.ErrorHTML, "500", "html", []) ==
             "Internal Server Error"
  end
end
