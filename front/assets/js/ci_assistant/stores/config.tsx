import { createContext } from "preact";

export interface CiAssistantConfig {
  gatewayWsUrl: string;
  hmacToken: string;
}

export const Context = createContext<CiAssistantConfig>({
  gatewayWsUrl: "",
  hmacToken: "",
});
