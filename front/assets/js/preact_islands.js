/**
 * @prettier
 */

//
// Preact islands mount into elements inside the body, and Turbo Drive discards
// the body without telling Preact about it.
//
// The components release their window and document listeners from useEffect
// cleanups, and those only run on unmount. Left alone, every visit to a page
// with an island leaves another live listener behind, pointing at DOM that is
// no longer in the document. So the roots have to be unmounted explicitly,
// while the old body is still in place.
//
// Islands defined as custom elements (preactement) look after themselves -
// removing them from the document fires disconnectedCallback.
//
import { render } from "preact";

const mounted = new Set();

//
// Records a container as holding a Preact root and returns it unchanged, so it
// can wrap an existing lookup at the point of mounting:
//
//   Agents({ dom: islandRoot(document.getElementById("agents-app")), config })
//
export function islandRoot(element) {
  if (element) {
    mounted.add(element);
  }

  return element;
}

//
// Unmounts every tracked root. render(null, container) is Preact's unmount:
// it diffs the tree away and runs the effect cleanups on the way out.
//
export function unmountIslands() {
  mounted.forEach((element) => render(null, element));
  mounted.clear();
}

//
// Exposed for tests.
//
export function trackedIslandCount() {
  return mounted.size;
}
