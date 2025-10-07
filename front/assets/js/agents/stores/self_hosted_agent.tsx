import { createContext } from "preact";
import * as types from "../types";

export type Action =
  | { type: `SET_AGENT_TYPE`, value: types.SelfHosted.AgentType }
  | { type: `SET_AGENTS`, value: types.SelfHosted.Agent[] }
  | { type: `SET_TOKEN`, value: string }
  | { type: `REVEAL_TOKEN` }
  | { type: `HIDE_TOKEN` }
  | { type: `JUST_CREATED` }
  | { type: `JUST_RESET` };

export interface State {
  token: string;
  _token: string;
  tokenRevealed: boolean;
  type?: types.SelfHosted.AgentType;
  agents: types.SelfHosted.Agent[];
  _typeJustCreated: boolean;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `JUST_CREATED`:
      return {
        ...state,
        _typeJustCreated: true,
      };

    case `JUST_RESET`:
      return {
        ...state,
        _typeJustCreated: false,
      };

    case `SET_AGENT_TYPE`:
      return {
        ...state,
        type: action.value,
      };

    case `SET_AGENTS`: {
      return {
        ...state,
        agents: action.value,
      };
    }

    case `SET_TOKEN`:
      return {
        ...state,
        _token: action.value,
      };

    case `REVEAL_TOKEN`:
      return {
        ...state,
        tokenRevealed: true,
        token: state._token,
      };

    case `HIDE_TOKEN`:
      return {
        ...state,
        tokenRevealed: false,
        token: `<YOUR TOKEN>`,
      };
    default:
      return state;
  }
};

export type Dispatcher = (action: Action) => void;

export const EmptyState: State = {
  _token: ``,
  token: ``,
  tokenRevealed: false,
  agents: [],
  _typeJustCreated: false,
};

export const Context = createContext<{
  state: State;
  dispatch: (a: Action) => void;
}>({ state: EmptyState, dispatch: () => undefined });
