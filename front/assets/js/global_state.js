export var GlobalState = {
  // This module is helper for setting up
  // the global windows state through query strings.
  //
  // 1. GlobalState.set(key, value)
  //    - Replaces the query key value with given one.
  //
  // 2. GlobalState.get(key)
  //    - Retrieves the query value for the given key.

  set: function(key, value) {
    var urlSearchParams = GlobalState.urlSearchParams();

    urlSearchParams.delete(key);
    urlSearchParams.append(key, value);

    window.history.pushState(null, null, `?${urlSearchParams.toString()}`);
  },

  get: function(key) {
    GlobalState.urlSearchParams().get(key);
  },

  urlSearchParams: function() {
    return new URLSearchParams(window.location.search);
  }
};
