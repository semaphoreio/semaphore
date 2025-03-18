// eslint-disable-next-line
import * as preact from "preact";
import { h } from "preact";
// In place for time-ago element defined in /assets/time_ago.js. Without these definitions relative-time element will not be visible for JSX.

interface TimeAgoProps extends h.JSX.HTMLAttributes<HTMLElement> {
  datetime: string;
}
// eslint-disable-next-line
declare module "preact" {
  namespace JSX {
    interface IntrinsicElements {
      [`time-ago`]: TimeAgoProps;
    }
  }
}