import { h, JSX } from "preact";

export const LockIcon: () => JSX.Element = () => {
  return (
    <svg height="16" width="16" xmlns="http://www.w3.org/2000/svg">
      <g fill="none" fillRule="evenodd">
        <path style="stroke: #00a569;" d="M8 1a3 3 0 013 3v3H5V4a3 3 0 013-3z" strokeWidth="2"/>
        <path style="stroke: none; fill: #00a569;" d="M13 6a1 1 0 011 1v8a1 1 0 01-1 1H3a1 1 0 01-1-1V7a1 1 0 011-1zM8 9a1 1 0 00-1 1v2a1 1 0 002 0v-2a1 1 0 00-1-1z"/>
      </g>
    </svg>
  );
};