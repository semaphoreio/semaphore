
import { useContext, useLayoutEffect, useReducer } from "preact/hooks";
import * as types from "../types";
import * as stores from "../stores";

export const InvoiceList = () => {
  const config = useContext(stores.Config.Context);
  const [state, dispatch] = useReducer(stores.Invoices.Reducer, { ... stores.Invoices.EmptyState, url: config.invoicesUrl } );

  if(!config.isBillingManager) {
    return null;
  }

  useLayoutEffect(() => {
    if(config.invoicesUrl) {
      const url = new URL(state.url, location.origin);

      dispatch({ type: `SET_STATUS`, value: stores.Invoices.Status.Loading });
      fetch(url, { credentials: `same-origin` })
        .then((response) => response.json())
        .then((json) => {
          const invoices = json.invoices.map(types.Spendings.Invoice.fromJSON) as types.Spendings.Invoice[];
          dispatch({ type: `SET_INVOICES`, invoices });
          dispatch({ type: `SET_STATUS`, value: stores.Invoices.Status.Loaded });
        }).catch((e) => {
          dispatch({ type: `SET_STATUS`, value: stores.Invoices.Status.Error });
          dispatch({ type: `SET_STATUS_MESSAGE`, value: `${e as string}` });
        });
    }
  }, [config.invoicesUrl]);

  const stateLoading = state.status == stores.Invoices.Status.Loading;
  const stateError = state.status == stores.Invoices.Status.Error;
  const stateLoadedEmpty = state.status == stores.Invoices.Status.Loaded && state.invoices.length == 0;
  const stateLoaded = state.status == stores.Invoices.Status.Loaded && state.invoices.length > 0;

  return (
    <div className="bb b--black-075 w-100-l mb4 br3 shadow-3 bg-white">
      <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top ">
        <div>
          <div className="flex items-center">
            <span className="material-symbols-outlined pr2">receipt_long</span>
            <div className="b">Invoice History</div>
          </div>
        </div>
      </div>

      <div className="pv2 ph3">
        {stateLoading && <div className="tc">Loading...</div>}
        {stateError && <div className="tc">Error: {state.statusMessage}</div>}
        {stateLoadedEmpty && <div className="tc">No invoices found.</div>}
        {stateLoaded && state.invoices.map((invoice, i) =>
          <Invoice
            invoice={invoice}
            key={i}
            lastItem={i == state.invoices.length - 1}
          />
        )}
      </div>
    </div>
  );
};

const Invoice = ({ invoice, lastItem }: { invoice: types.Spendings.Invoice, lastItem?: boolean }) => {
  return (
    <div className={ lastItem ? `` : `b--black-075 bb`}>
      <div className="ph3 pv2">
        <div className="flex items-center-ns">
          <div className="w-100">
            <div className="flex-ns items-center">
              <div className="w-80-ns"><a href={invoice.url}>{invoice.name}</a></div>
              <div className="w-20-ns tr-ns tnum">{invoice.total}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
