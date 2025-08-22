import { h } from "preact";
import { useState } from "preact/hooks";
import * as toolbox from "js/toolbox";

interface BoxProps extends h.JSX.HTMLAttributes<HTMLDivElement> {
  type: `danger` | `warning` | `info`;
  copyContent?: string;
  showCopy?: boolean;
}

export const Box = (props: BoxProps) => {
  const [copied, setCopied] = useState(false);
  const [anchorFocused, setAnchorFocused] = useState(false);

  const { type, copyContent, showCopy = false, className = ``, children, ...rest } = props;

  const onCopyClick = () => {
    if (copyContent) {
      void navigator.clipboard.writeText(copyContent);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const getColorClasses = () => {
    switch (type) {
      case `danger`:
        return `bg-washed-red b--red`;
      case `warning`:
        return `bg-washed-yellow b--yellow`;
      case `info`:
        return `bg-washed-blue b--blue`;
    }
  };

  const getIcon = () => {
    switch (type) {
      case `danger`:
        return <toolbox.MaterializeIcon name="error" className="f4 red mr2"/>;
      case `warning`:
        return <toolbox.MaterializeIcon name="warning" className="f4 gold mr2"/>;
      case `info`:
        return <toolbox.MaterializeIcon name="info" className="f4 blue mr2"/>;
    }
  };

  const copyButton = showCopy && copyContent && (
    <div
      className="absolute"
      style={{
        right: `0.5rem`,
        top: `0.5rem`,
      }}
    >
      <toolbox.Tooltip
        content="Copy to clipboard"
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
      className={`f6 ba br3 relative ${getColorClasses()} ${className as string}`}
      onMouseOver={() => setAnchorFocused(true)}
      onMouseOut={() => setAnchorFocused(false)}
      {...rest}
    >
      <div className="flex items-start pa3">
        {getIcon()}
        <div className="flex-auto">
          {typeof children === `string` ? (
            <div dangerouslySetInnerHTML={{ __html: children }}/>
          ) : (
            children
          )}
        </div>
      </div>
      {copyButton}
    </div>
  );
};
