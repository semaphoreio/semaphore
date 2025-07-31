import { useState } from "preact/hooks";

interface TokenDisplayProps {
  token: string;
  onClose: () => void;
}

export const TokenDisplay = ({ token, onClose }: TokenDisplayProps) => {
  const [copied, setCopied] = useState(false);

  const copyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(token);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      // Failed to copy token
    }
  };

  return (
    <div className="pa4">
      <div className="mb3">
        <h3 className="f4 mb2">API Token Generated</h3>
        <p className="f6 gray mb3">
          This token will only be shown once. Please copy it and store it securely.
        </p>
      </div>

      <div className="bg-washed-yellow ba b--gold br2 pa3 mb3">
        <div className="flex items-center justify-between">
          <code className="f6 truncate mr2" style={{ maxWidth: `80%` }}>
            {token}
          </code>
          <button
            className="btn btn-secondary btn-sm flex items-center"
            onClick={() => void copyToClipboard()}
          >
            <span className="material-symbols-outlined mr1 f6">
              {copied ? `check` : `content_copy`}
            </span>
            {copied ? `Copied!` : `Copy`}
          </button>
        </div>
      </div>

      <div className="bg-washed-red ba b--red br2 pa2 mb3">
        <p className="f6 mb0 red">
          <strong>Warning:</strong> This token provides API access to your organization.
          Keep it secure and do not share it publicly.
        </p>
      </div>

      <div className="flex justify-end">
        <button className="btn btn-primary" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  );
};
