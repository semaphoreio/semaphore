import { Box } from "js/toolbox";

interface TokenDisplayProps {
  token: string;
  onClose: () => void;
}

export const TokenDisplay = ({ token, onClose }: TokenDisplayProps) => {
  return (
    <div className="pa3">
      <div className="mb3">
        <h3 className="f4 mb2">API Token Generated</h3>
        <p className="f6 gray mb3">
          This token will only be shown once. Please copy it and store it securely.
        </p>
      </div>

      <Box type="info" className="mb3" showCopy={true} copyContent={token}>
        {token}
      </Box>

      <Box type="warning" className="mb3">
        This token provides API access to your organization.
        <br/>
        Keep it secure and do not share it publicly.
      </Box>

      <div className="flex justify-end">
        <button className="btn btn-primary" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  );
};
