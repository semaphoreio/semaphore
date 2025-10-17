import { createContext } from "preact";
import type * as types from "../types";

export interface State {
  baseUrl: string;
  spendings: any[];
  currentSpending: any;
  selectedSpendingId: string;
  seatsUrl: string;
  costsUrl: string;
  invoicesUrl: string;
  spendingCsvUrl: string;
  projectsCsvUrl: string;
  creditsUrl: string;
  budgetUrl: string;
  upgradeUrl: string;
  newOrganizationUrl: string;
  canUpgradeUrl: string;
  budget?: any;
  isBillingManager: boolean;
  forceColdBoot?: boolean;
  projectSpendings?: any;
  availablePlans?: types.Plans.Plan[];
  currentPlanType?: string;
  peoplePageUrl: string;
  agentsPageUrl: string;
  contactSupportUrl: string;
}

export const Context = createContext<State>({
  baseUrl: ``,
  spendings: [],
  currentSpending: {},
  selectedSpendingId: ``,
  seatsUrl: ``,
  costsUrl: ``,
  invoicesUrl: ``,
  spendingCsvUrl: ``,
  projectsCsvUrl: ``,
  creditsUrl: ``,
  budgetUrl: ``,
  upgradeUrl: ``,
  newOrganizationUrl: ``,
  canUpgradeUrl: ``,
  isBillingManager: false,
  forceColdBoot: false,
  availablePlans: [],
  currentPlanType: ``,
  agentsPageUrl: ``,
  peoplePageUrl: ``,
  contactSupportUrl: ``,
});
