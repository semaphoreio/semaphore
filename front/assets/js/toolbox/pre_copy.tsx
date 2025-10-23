import { h } from "preact";
import * as toolbox from "js/toolbox";
import { useState } from "preact/hooks";
import dedent from "dedent";

interface PreCopyProps extends h.JSX.HTMLAttributes {
  content: string;
  title?: string;
}

export default (props: PreCopyProps) => {
  const [copied, setCopied] = useState(false);
  const [anchorFocused, setAnchorFocused] = useState(false);
  const onCopyClick = () => {
    void navigator.clipboard.writeText(dedent(props.content));
    setCopied(true);
  };

  let title = null;
  if (props.title) {
    title = <div className="bb b--black-10 mb0 ph2 pv1 ">{props.title}</div>;
  }

  const anchor = (
    <div
      className="absolute"
      style={{
        right: `0.5rem`,
        top: `0.25rem`,
      }}
    >
      <toolbox.Tooltip
        content={`Copy to clipboard`}
        anchor={
          <button
            className={`btn pa1 btn-secondary btn-tiny ${
              anchorFocused ? `` : `o-50`
            }`}
            onClick={onCopyClick}
          >
            {!copied && (
              <div className="flex items-center gray f6">
                <toolbox.MaterializeIcon name="content_copy" className="f4"/>
              </div>
            )}
            {copied && (
              <div className="flex items-center gray f6">
                <toolbox.MaterializeIcon name="done" className="f4"/>
              </div>
            )}
          </button>
        }
        placement="top"
      />
    </div>
  );
  return (
    <div
      className={
        `f6 bg-washed-yellow mb0 ba b--black-075 br3 ` +
        (props.className as string)
      }
      onMouseOver={() => setAnchorFocused(true)}
      onMouseOut={() => {
        setAnchorFocused(false);
      }}
    >
      {title}
      <div className="flex flex-column relative pr4">
        <div className="mb0 ph3 pv2">
          <pre className="ma0 overflow-x-auto">{dedent(props.content)}</pre>
        </div>
        {anchor}
      </div>
    </div>
  );
};
