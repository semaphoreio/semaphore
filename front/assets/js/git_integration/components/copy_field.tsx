import { Fragment } from "preact";
import { useState } from "preact/hooks";

interface CopyFieldProps {
  title?: string;
  url: string | string[];
}

export const CopyField = ({ title, url }: CopyFieldProps) => {
  const [copyIcon, setIcon] = useState(copyElement);
  const urls = Array.isArray(url) ? url : [url];

  const copyTextToClipboard = () => {
    const textToCopy = Array.isArray(url) ? url.join(`\n`) : url;
    navigator.clipboard.writeText(textToCopy).then(
      () => {
        setIcon(copiedElement);
        setTimeout(() => {
          setIcon(copyElement);
        }, 2000);
      },
      () => {
        return;
      }
    );
  };

  return (
    <Fragment>
      <div className="flex items-center justify-between">
        <p className="f5 mv2">{title}</p>
        <button
          onClick={copyTextToClipboard}
          className=""
          style={{
            background: `none`,
            border: `none`,
            padding: 0,
            cursor: `pointer`,
            color: `inherit`,
          }}
        >
          {copyIcon}
        </button>
      </div>
      <pre className="f6 bg-washed-yellow mb3 ph3 pv2 ba b--black-075 br3 overflow-auto">
        {urls.map((u, i) => (
          <Fragment key={i}>
            {u}
            {i < urls.length - 1 && `\n`}
          </Fragment>
        ))}
      </pre>
    </Fragment>
  );
};

const copiedElement = <span className="gray f5 pointer pa1 ml3">copied</span>;
const copyElement = (
  <span className="material-symbols-outlined f5 b pointer pa1 ml3">
    content_copy
  </span>
);
