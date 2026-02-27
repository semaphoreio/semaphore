import { createContext } from "preact";

export interface CiAssistantConfig {
  hmacToken: string;
}

export const Context = createContext<CiAssistantConfig>({
  hmacToken: "",
});
