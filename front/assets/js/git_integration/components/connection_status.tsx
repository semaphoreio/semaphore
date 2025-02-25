
import * as types from "../types";

interface Props {
  status: types.Integration.IntegrationStatus;
}

export const ConnectionStatus = ({ status }: Props) => {
  if (status === types.Integration.IntegrationStatus.Connected) {
    return connectionOkSvg;
  }

  return (
    <span className="f6 normal ml1 ph1 br2 bg-red white pointer">
      Disconnected
    </span>
  );
};

const connectionOkSvg = (
  <svg
    height="16"
    width="16"
    className="v-mid"
    xmlns="http://www.w3.org/2000/svg"
  >
    <g fill="none" fillRule="evenodd">
      <circle cx="8" cy="8" fill="#00a569" r="8"></circle>
      <path
        d="M7.456 8.577L6.273 7.45a1 1 0 00-1.38 1.448l1.917 1.826a1 1 0 001.423-.044l3.386-3.652a1 1 0 00-1.466-1.36z"
        fill="#fff"
        fillRule="nonzero"
      ></path>
    </g>
  </svg>
);
