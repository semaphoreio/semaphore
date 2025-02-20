import { State } from "./state"
import { Scroll } from "./scroll"

export var Live = {
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

    const observer = new MutationObserver(callback);

    observer.observe(container, config);

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
