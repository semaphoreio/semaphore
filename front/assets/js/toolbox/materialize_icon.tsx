import { h } from "preact";
import { HTMLAttributes } from "preact/compat";

export default function ({
  name: name,
  className: className,
  ...props
}: { name: string, } & Partial<HTMLAttributes<HTMLElement>>) {
  return (
    <span
      className={`${
        className ? (className as string) : ``
      } material-symbols-outlined`}
      {...props}
    >
      {name}
    </span>
  );
}
