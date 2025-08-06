/**
 * @prettier
 */

//
// This is a generic poll algorithm.
//
// Define following attributes on DOM nodes:
//
//   data-poll-state      - State of polling. 'done' or 'poll'.
//   data-poll-href       - endpoint that renders this element.
//   data-poll-param-*    - Pass additional parameters as query parameters.
//   data-poll-background - Container will be refresh also when the tab is not visible
//
//
// Example:
//
//   === Active pollable element
//
//   <div data-poll-href="/pipelines/121" data-poll-state=poll>
//     <p>Hi!</p>
//   </div>
//
//   === Finished pollable element
//
//   <div data-poll-href="/pipelines/121" data-poll-state=done>
//     <p>Hi!</p>
//   </div>
//
// Stopping Pollman:
//
//   Pollman.stop() - Stops pollman from fetching and replacing html fragments.
//                    Useful for inspecting html without the worry that
//                    Pollman will replace it.
//
// And starting again:
//
//   Pollman.start() - opposite of stop()
//
// Triggering an update immediately:
//
//   Pollman.pollNow() - Polls for updates and replaces the elements immidiately.
//
//     options:
//       - refreshAll - [boolean] If set to true, pollman will update even the
//                                elements that have data-poll-state=done.
//       - only       - [string] Additional jQuery selector to poll only specified elements with data-poll-state=poll.
//
// Passing additional query parameters when fetching (selected=true):
//
//    <div data-poll-href="/pipelines/121" data-poll-state=poll data-poll-param-selected='true'>
//      <p> Hey! </p>
//    </div>

import _ from "lodash";
import $ from "jquery";

export var Pollman = {
  init: function (options) {
    this.options = _.defaults(options || {}, {
      interval: 2000,
      saveScrollElements: [],
      forceRefreshCycle: 30,
      startLooper: true
    });

    this.urlsInProgress = [];
    this.fetchesInProgress = [];
    this.pollable_elements = [];

    this.noRefreshCycle = 0;

    if(this.options.startLooper) {
      this.looper();
    }
  },

  pollNow: function (options, callback) {
    this.poll(options, callback);
  },

  stop: function () {
    this.stopped = true;
    this.forgetFetchInProgress();
  },

  forgetFetchInProgress: function () {
    this.fetchesInProgress = [];
  },

  start: function () {
    this.stopped = false;
  },

  poll: function (options, callback) {
    let elements = this.elementsToRefresh(options);
    Array.from(elements).forEach(function (node) {
      Pollman.fetchAndReplace(node, callback);
    });
  },

  elementsToRefresh: function (options) {
    options = options || {};
    let refreshAll = options.refreshAll === true;
    let forceRefresh = !!options.forceRefresh;

    let elements;
    if (this.shouldRefresh(forceRefresh)) {
      this.noRefreshCycle = 0;

      if (refreshAll) {
        elements = document.querySelectorAll("[data-poll-href]");
      } else {
        elements = document.querySelectorAll(
          "[data-poll-href]:not([data-poll-state=done])"
        );
      }
    } else {
      this.noRefreshCycle = this.noRefreshCycle + 1;

      elements = document.querySelectorAll(
        "[data-poll-href][data-poll-background]:not([data-poll-state=done])"
      );
    }

    return elements;
  },

  shouldRefresh: function(force) {
    force = (typeof force !== 'undefined') ? force : false;

    return force || this.pageIsVisible() || this.forceRefreshTime();
  },

  pageIsVisible: function () {
    return document.visibilityState == "visible";
  },

  forceRefreshTime: function() {
    if(this.options.forceRefreshCycle < 0) {
      return false
    } else {
      return this.noRefreshCycle >= this.options.forceRefreshCycle;
    }
  },

  looper: function () {
    if (!this.stopped) {
      this.poll(this.options);
    }

    setTimeout(this.looper.bind(this), this.options.interval);
  },

  startForUrl: function (url) {
    this.urlsInProgress.push(url)
  },

  urlInProgress: function (url) {
    return this.urlsInProgress.includes(url)
  },

  finishForUrl: function (url) {
    this.urlsInProgress = this.urlsInProgress.filter(u => u !== url)
  },

  fetchAndReplace: function (node, callback) {
    let url;

    try {
      url = Pollman.requestUrl(node);
    } catch (error) {
      console.error('Invalid poll URL, removing element:', error);
      // Remove the invalid polling element to prevent further attempts
      $(node).remove();
      return;
    }

    if (this.urlInProgress(url)) {
      return;
    }

    let newFetch = this.rememberFetch(Date.now());
    this.startForUrl(url);

    fetch(url, { credentials: "same-origin" })
      .then(function (response) {
        if (response.status >= 200 && response.status < 300) {
          return response.text();
        } else {
          throw "Server failed to respond with status 2xx";
        }
      })
      .then((body) => {
        if (Pollman.remembers(newFetch)) {
          this.withScrollSaved(document, () => {
            $(node).replaceWith(body);
          });
        }
      })
      .then(callback)
      .catch(function (error) {
        console.log("Network error. Retrying.");
        console.log(error);
      })
      .finally(() => {
        this.finishForUrl(url);
      });
  },

  // 🙈
  withScrollSaved: function (parent, callback) {
    let elements = _.concat([parent], this.options.saveScrollElements)

    elements = _.map(elements, (e) => {
      return {
        element: e,
        topScroll: $(e).scrollTop(),
        leftScroll: $(e).scrollLeft()
      }
    })

    callback();

    elements = _.reverse(elements);
    _.each(elements, (e) => {
      $(e.element).scrollTop(e.topScroll);
      $(e.element).scrollLeft(e.leftScroll);
    })
  },

  remembers: function (fetchEvent) {
    return this.fetchesInProgress.includes(fetchEvent);
  },

  rememberFetch: function (newFetch) {
    this.fetchesInProgress.push(newFetch);

    return newFetch;
  },

  requestUrl: function (node) {
    const pollHref = node.getAttribute("data-poll-href");

    try {
      const pollUrl = new URL(pollHref, window.location.origin);

      // Only allow same origin (same protocol, host, and port)
      if (pollUrl.origin !== window.location.origin) {
        console.error(`Blocked data-poll-href to unauthorized host: ${pollUrl.origin}`);
        throw new Error(`data-poll-href must be same-origin. Got: ${pollUrl.origin}, Expected: ${window.location.origin}`);
      }

      // Build query parameters from data-poll-param-* attributes (existing logic)
      var queryParams = new URLSearchParams();
      Array.from(node.attributes).forEach(function (attribute) {
        if (attribute.name.startsWith("data-poll-param-")) {
          var name = attribute.name.substring("data-poll-param-".length);
          queryParams.append(name, attribute.value);
        }
      });

      return `${pollUrl.href}?${queryParams}`;

    } catch (error) {
      console.error('Invalid data-poll-href URL:', pollHref, error);
      throw new Error('Invalid or unauthorized data-poll-href URL');
    }
  },
};
