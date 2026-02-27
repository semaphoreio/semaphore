import { ConnectionStatus as Status } from "../types";

interface Props {
  status: Status;
}

export function ConnectionStatus({ status }: Props) {
  if (status === "connected") return null;

  const labels: Record<string, string> = {
    connecting: "Connecting...",
    disconnected: "Disconnected",
    reconnecting: "Reconnecting...",
  };

  const colors: Record<string, string> = {
    connecting: "bg-light-yellow dark-gray",
    disconnected: "bg-washed-red dark-red",
    reconnecting: "bg-light-yellow dark-gray",
  };

  return (
    <div class={`pa2 tc f6 ${colors[status] || ""}`}>
      {labels[status] || status}
    </div>
  );
}
