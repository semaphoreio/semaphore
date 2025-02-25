import { ComponentChildren } from "preact";
import * as stores from "../stores";

interface Props {
  children: ComponentChildren;
  initialState?: stores.Create.Provider.State;
}

export const ProviderProvider = ({ children, initialState }: Props) => {
  const store = stores.Create.Provider.useProviderStore(initialState);

  return (
    <stores.Create.Provider.Context.Provider value={store}>
      {children}
    </stores.Create.Provider.Context.Provider>
  );
};
