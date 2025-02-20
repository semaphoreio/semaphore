import { h } from "preact";
import * as types from "../types";
import * as toolbox from "js/toolbox";

interface UsageCreditsProps {
  credits: types.Credits.Balance[];
}

export const CreditsBalance = (props: UsageCreditsProps) => {
  return <div className="w-100-l mb4 br3 shadow-3 bg-white">
    <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top">
      <div>
        <div className="flex items-center">
          <span className="material-symbols-outlined pr2">calendar_month</span>
          <div className="b mr1">Credit balance history</div>
        </div>
      </div>
    </div>
    <div>
      <div className="bb b--black-075">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-20-ns gray">Date</div>
                <div className="w-60-ns tnum gray">Description</div>
                <div className="w-20-ns tr-ns tnum gray">Balance change</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <ListUsageCredits credits={props.credits}/>
    </div>
  </div>;
};

const ListUsageCredits = (props: UsageCreditsProps) => {
  const isLastItem = (idx: number) => {
    return idx === props.credits.length - 1;
  };

  return <div className={`b--black-075`}>
    {props.credits.map((credit, idx) => {
      return <div className={`ph3 pv2 b--black-075 ${isLastItem(idx) ? `` : `bb`}`} key={idx}>
        <div className="flex items-center-ns">
          <div className="w-100">
            <div className="flex-ns items-center">
              <div className="w-20-ns">{toolbox.Formatter.dateFull(credit.occuredAt)}</div>
              <div className="w-60-ns tnum">{credit.description}</div>
              <div className="w-20-ns tr-ns tnum">
                {credit.type === types.Credits.BalanceType.Charge && <span className="red">- {credit.amount}</span>}
                {credit.type === types.Credits.BalanceType.Deposit && <span className="green">+ {credit.amount}</span>}
              </div>
            </div>
          </div>
        </div>
      </div>;
    })}
    {props.credits.length === 0 && <div className="gray tc mv2">No balance history</div>}
  </div>;
};
