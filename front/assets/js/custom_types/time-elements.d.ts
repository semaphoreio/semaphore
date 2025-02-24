// eslint-disable-next-line
import * as preact from "preact";
import { h } from "preact";
// In place for time-elements library. Without these definitions relative-time element will not be visible for JSX.

interface RelativeTimeProps extends h.JSX.HTMLAttributes<HTMLElement> {
  dateTime: string;
}
// eslint-disable-next-line
declare module "preact" {
  namespace JSX {
    interface IntrinsicElements {
      [`relative-time`]: RelativeTimeProps;
    }
  }
}
