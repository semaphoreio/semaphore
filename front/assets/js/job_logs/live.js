import { State } from "./state"
import { Scroll } from "./scroll"

export var Live = {
  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
      this.observer = null
    }
  },

  init(containerSelector) {
    const container = document.querySelector(containerSelector)
    const config = { childList: true, subtree: true }

    const callback = function(mutationsList, observer) {
      if (State.get('live') && State.get("state") == "running") {
        for(let mutation of mutationsList) {
          if (mutation.type === 'childList') {
            if (mutation.addedNodes.length > 0) {
              Scroll.bottom(container)
            }
          }
        }
      }
    };

    // Kept on the module so the Turbo teardown can disconnect it. The observed
    // node lives in the body and goes away with it, but an observer nothing
    // holds a reference to can never be stopped explicitly.
    this.disconnect()
    this.observer = new MutationObserver(callback);

    this.observer.observe(container, config);

    // https://stackoverflow.com/a/31223774/3887547
    let lastScrollTop = 0;
    container.addEventListener('scroll', function(){
      let st = container.scrollTop;
      if (["in_progress"].includes(State.get("fetching"))) {
        if (st < lastScrollTop){
          State.set('live', false)
        }
      }
      lastScrollTop = st <= 0 ? 0 : st;
    }, false);

  }
}
