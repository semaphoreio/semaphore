import moment from "moment";

export const decimalThousands = (value: number): string => {
  return value.toString().replace(/\B(?=(\d{3})+(?!\d))/g, `,`);
};

export const decimalThousandsWithPrecision = (value: number, precision: number): string => {
  // format the value with the given precision
  value = parseFloat(value.toFixed(precision));
  const stringValue = value.toFixed(precision);

  // split the value into the integer and decimal parts
  const parts = stringValue.split(`.`);
  // format the integer part with thousands separators
  parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, `,`);

  // return the formatted value
  return parts.join(`.`);
};

export const stringToHexColor = (str: string, opacity = 100): string => {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = str.charCodeAt(i) + ((hash << 5) - hash);
  }

  let color = `#`;
  for (let i = 0; i < 3; i++) {
    const value = (hash >> (i * 8)) & 0xff;
    color += `00${value.toString(16)}`.substr(-2);
  }

  // Convert the opacity percentage to a hex value and append it.
  const alpha = Math.round((opacity * 255) / 100);
  color += `00${alpha.toString(16)}`.substr(-2);
  return color;
};

export const humanize = (str: string): string => {
  str = str.replace(/_/g, ` `);
  str = str.replace(/-/g, ` `);
  str = str.replace(/([a-z])([A-Z])/g, `$1 $2`);
  str = str.replace(/\w\S*/g, (txt) => {
    return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
  });
  return str;
};

export const colorFromName = (str: string): string => {
  switch (str) {
    // Billing UI
    case `machine_time`:
      return `#2196F3`;
    case `seats`:
      return `#8658d6`;
    case `storage`:
      return `#fd7e14`;
    case `addons`:
      return `#00a569`;
    //
    // Machines
    case `e1-standard-2`:
      return `#330d56`;
    case `e1-standard-4`:
      return `#450d56`;
    case `e1-standard-8`:
      return `#570d56`;
    case `e2-standard-2`:
      return `#82b207`;
    case `e2-standard-4`:
      return `#94b207`;
    case `e2-standard-8`:
      return `#06b207`;
    //
    default:
      return stringToHexColor(str);
  }
};

export const toMoney = (value: number): string => {
  const amount = decimalThousandsWithPrecision(value, 2);
  return `$${amount}`;
};

export const dateFull = (date: Date): string => {
  return moment(date).format(`MMM, Do YYYY`);
};

export const parseMoney = (value: string): number => {
  return parseFloat(value.replace(`$`, ``).replace(` `, ``).replace(`,`, ``));
};

export const parseDateToUTC = (dateString: string): Date => {
  const parsedDate = moment.utc(dateString);
  return new Date(parsedDate.year(), parsedDate.month(), parsedDate.date());
};

export const formatTestDuration = (value: number): string => {
  value = Math.floor(value);
  if (value < 100) {
    return `${value}ms`;
  } else if (value >= 100 && value < 60000) {
    const seconds = value / 1000;
    return `${seconds.toFixed(2)}s`;
  } else {
    const totalSeconds = Math.floor(value / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, `0`)}min`;
  }
};

/**
 * Formats a date string into a "time ago" format (e.g., "5 minutes ago").
 * Uses the moment.js library for formatting.
 * @param dateStr - The date string to format.
 * @returns A string representing the time elapsed since the given date.
 */
export const formatTimeAgo = (dateStr: string) => {
  const date = new Date(dateStr);
  return moment(date).fromNow();
};
