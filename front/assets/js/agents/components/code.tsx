import type { h } from "preact";
interface CodeProps extends h.JSX.HTMLAttributes {
  content: string;
}

export const Code = (props: CodeProps) => {
  return (
    <span
      style="white-space: nowrap;"
      className="bg-washed-yellow ph1 mh1 ba b--black-075 br3"
    >
      {props.content}
    </span>
  );
};
