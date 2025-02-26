
import * as toolbox from "js/toolbox";
import * as types from "../types";
import * as stores from "../stores";
import { useContext } from "preact/hooks";


interface AvailableCreditsProps {
  credits: types.Credits.Available[];
}

export const AvailableCredits = (props: AvailableCreditsProps) => {
  const { state } = useContext(stores.Spendings.Context);
  const currentCredits = state.currentSpending.summary.creditsStarting;

  const tooltipContent = <div className="f5">
    <div className="mb2">
      <div className="b">What is this?</div>
      <div className="mb2">Your monthly spending will always be substracted first from the credits batch with the earliest expiry date.</div>
      <div className="">Credits batches that have expired or were consumed are not displayed.</div>
    </div>
  </div>;

  return <div className="bb b--black-075 w-100-l mb4 br3 shadow-3 bg-white">
    <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top">
      <div>
        <div className="flex items-center">
          <span className="material-symbols-outlined pr2">payments</span>
          <div className="b mr1">Available credits</div>

          <toolbox.Popover
            anchor={<toolbox.Asset path="images/icn-info-15.svg" className={`pointer`}/>}
            content={tooltipContent}
          />
        </div>
      </div>
    </div>
    <div>
      <div className="bb b--black-075">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-20-ns gray">Date expiring</div>
                <div className="w-20-ns tnum gray">Date added</div>
                <div className="w-40-ns tnum gray">Type</div>
                <div className="w-20-ns tr-ns tnum gray">Credits remaining</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <ListAvailableCredits credits={props.credits}/>

    </div>
    <div>
      <div className="flex items-center justify-between pa3 bt bw1 b--black-075">
        <div className="flex items-center pl4">
        </div>
        <div className="flex items-center">
          <span className="b">{currentCredits}</span>
        </div>
      </div>
    </div>
  </div>;
};

const ListAvailableCredits = (props: AvailableCreditsProps) => {
  const isLastItem = (idx: number) => {
    return idx === props.credits.length - 1;
  };

  return <div className={`b--black-075`}>
    {props.credits.map((credit, idx) => {
      return <div className={`ph3 pv2 b--black-075 ${isLastItem(idx) ? `` : `bb`}`} key={idx}>
        <div className="flex items-center-ns">
          <div className="w-100">
            <div className="flex-ns items-center">
              <div className="w-20-ns">{toolbox.Formatter.dateFull(credit.expiresAt)}</div>
              <div className="w-20-ns tnum">{toolbox.Formatter.dateFull(credit.givenAt)}</div>
              <div className="w-40-ns tnum">{credit.typeName}</div>
              <div className="w-20-ns tr-ns tnum">
                <span className="green">{credit.amount}</span>
              </div>
            </div>
          </div>
        </div>
      </div>;
    })}
    {props.credits.length === 0 && <div className="gray tc mv2">No credits available</div>}
  </div>;
};
