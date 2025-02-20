import { v4 as uuid } from "uuid"
import $ from "jquery"
import _ from "lodash"

// Http.get(url, callback)
//
// Example:
//  Http.get("/check_setup", function(response) {
//    console.log(response)
//  });
//
// ---
//
// Http.post(url, body, callback)
//
// Example
//  Http.post("/create", {"name": "gonzales"}, function(response) {
//    console.log(response)
//  });
//
// ---
//
//  Features:
//
//  1. Retry
//
//  Both actions are retried in case of not-OK responses. The retry mechanism
//  is not configurable with the current implementation. Currently supported retry
//  mechanism starts with interval of 1s and increases lineary for 1s up
//  to 10s. After reaching 10s interval the action will be retried every 10s
//  until OK response is received.
//
//  2. Idempotency
//
//  To preserve idempotency when retrying requests, Http.post generates
//  the v4 UUID which is sent within each try of the POST request. The UUID of
//  the request supplied as Idempotency-Key header. Make sure to read this
//  header on the backend in order to preserve idempotency of your endpoint.

export var Http = {
  request: (method, url, body, callback, headers, options) => {
    fetch(url, {method: method, body: body, headers: headers})
    .then((response) => {
      if(response.ok) {
        callback(response);
      } else {
        options = options || {
          interval: 1000,
          linearBackoff: 1000,
          maxInterval: 10000
        };

        let timeoutInterval = Math.min(options.interval, options.maxInterval);

        options.interval = options.interval + options.linearBackoff;
        setTimeout(Http.request.bind(null, method, url, body, callback, headers, options), timeoutInterval);
      }
    });
  },

  get: (url, callback, options) => {
    return Http.request("GET", url, null, callback, {}, options)
  },

  post: (url, body, callback, headers, options) => {
    headers = _.merge({
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key": uuid(),
      "X-CSRF-Token": $("meta[name='csrf-token']").attr("content")
    }, headers || {})

    return Http.request("POST", url, body, callback, headers, options)
  },

  delete: (url, body, callback, headers, options) => {
    headers = _.merge({
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key": uuid(),
      "X-CSRF-Token": $("meta[name='csrf-token']").attr("content")
    }, headers || {})

    return Http.request("DELETE", url, body, callback, headers, options)
  },

  postJson: (url, body, callback, headers, options) => {
    headers = _.merge({
      'Content-Type': 'application/json'
    }, headers || {})

    return Http.post(url, JSON.stringify(body), callback, headers, options)
  }
}
