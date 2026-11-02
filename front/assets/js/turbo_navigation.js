/**
 * @prettier
 */

//
// Turbo Drive integration.
//
// Semaphore is a server rendered app: every page ships its own inline
// <script> blocks that populate window.InjectedDataByBackend, and app.js
// dispatches to a per-page init function based on InjectedDataByBackend.JS.
//
// Turbo swaps the <body> without reloading the document, which breaks three
// assumptions that hold on a full page load:
//
//   1. app.js runs once per page. Under Turbo the bundle lives in <head> and
//      is never re-executed, so the per-page dispatch has to be driven by
//      turbo:load instead of by module top-level code.
//
//   2. InjectedDataByBackend starts empty. The <head> block that initializes
//      it is not re-run, so keys set by the previous page would leak into the
//      next one. We reset it before each render.
//
//   3. Handlers bound in init() live as long as the page. They don't: Turbo
//      replaces the <body> element, so anything bound to document.body dies
//      with it, while anything bound to window or document survives and would
//      stack up one copy per visit. See runOnce/runPage in app.js.
//
export const TurboNavigation = {
  //
  // Starts Turbo Drive, unless the backend disabled it for this organization.
  //
  // onPageLoad     - runs after every render, including the first one.
  // onPageTeardown - runs before every render, to release the previous page.
  //
  // Returns true when Turbo took over navigation. When it did not, onPageLoad
  // is invoked synchronously, so a page with the flag off boots exactly the way
  // it did before Turbo existed.
  //
  start: function ({ onPageLoad, onPageTeardown }) {
    if (!this.isEnabled()) {
      onPageLoad();
      return false;
    }

    this.loadTurbo({ onPageLoad, onPageTeardown });

    return true;
  },

  //
  // Turbo is imported lazily because merely importing it builds a Session, a
  // ProgressBar and the turbo-frame/turbo-stream custom elements. Deferring
  // that keeps the import free of side effects for the majority of orgs that
  // have the flag off, and keeps this module loadable outside a browser.
  //
  // Note this defers evaluation, not download: build.js bundles without
  // splitting, so Turbo ships inside app.js for every organization either way.
  //
  loadTurbo: function ({ onPageLoad, onPageTeardown }) {
    return import("@hotwired/turbo").then((Turbo) => {
      document.addEventListener("turbo:before-render", () => {
        onPageTeardown();
        this.resetInjectedData();
      });

      document.addEventListener("turbo:load", () => {
        this.pruneDuplicateNonceTags();
        onPageLoad();
      });

      //
      // Link navigation only, for now.
      //
      // Turbo also intercepts form submissions, but it requires the response to
      // be a redirect and treats a rendered 200 as an error. Plenty of our
      // controllers re-render the form with a 200 when validation fails, so
      // enabling this would need every form flow audited first.
      //
      Turbo.config.forms.mode = "off";

      Turbo.start();
    });
  },

  isEnabled: function () {
    return window.InjectedDataByBackend.TurboNavigation === true;
  },

  //
  // Mirrors the initialization in the <head> of _head.html.eex. That block is
  // not re-executed by Turbo, so without this every page would inherit the
  // previous page's keys (a stale pipelineStatusUrl, FilterOptions, etc.).
  //
  resetInjectedData: function () {
    const preserved = {
      Environment: window.InjectedDataByBackend.Environment,
      Posthog: window.InjectedDataByBackend.Posthog,
      TurboNavigation: window.InjectedDataByBackend.TurboNavigation,
    };

    window.InjectedDataByBackend = { Watchman: {} };
    Object.assign(window.InjectedDataByBackend, preserved);
  },

  //
  // Turbo reads the first meta[name="csp-nonce"] in the document and stamps it
  // onto the scripts it injects. That first tag has to stay the one from the
  // originally loaded page, because the CSP header being enforced is still that
  // page's header - the document was never reloaded.
  //
  // Turbo's head merge appends the incoming page's nonce tag rather than
  // replacing it, so the original stays first and keeps winning. The appended
  // copies are dead weight that would otherwise grow by one per visit.
  //
  pruneDuplicateNonceTags: function () {
    const tags = document.querySelectorAll('meta[name="csp-nonce"]');

    for (let i = 1; i < tags.length; i++) {
      tags[i].remove();
    }
  },
};
