import { createContext } from "preact";
import * as types from "../types";

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
  budget?: any;
  isBillingManager: boolean;
  projectSpendings?: any;
  availablePlans?: types.Plans.Plan[];
  currentPlanType?: string;
  peoplePageUrl: string;
  agentsPageUrl: string;
  contactSupportUrl: string;
  pricingUrl: string;
  addonsUrl?: string;
  updateAddonUrl?: string;
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
  isBillingManager: false,
  availablePlans: [],
  currentPlanType: ``,
  agentsPageUrl: ``,
  peoplePageUrl: ``,
  contactSupportUrl: ``,
  pricingUrl: ``,
});
