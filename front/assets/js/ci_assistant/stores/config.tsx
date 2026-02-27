import { createContext } from "preact";

export interface CiAssistantConfig {
  socketToken: string;
}

export const Context = createContext<CiAssistantConfig>({
  socketToken: "",
});
