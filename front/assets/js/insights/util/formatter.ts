import moment from "moment";

const isZeroDate = (date: Date): boolean => {
  return moment(date).unix() == 0;
};

export const Formatter = {
  dateDiff: (durationStart: Date, durationEnd: Date): string => {
    if(isZeroDate(durationStart) || isZeroDate(durationEnd)) {
      return `N/A`;
    }

    const dateDiff = moment(durationStart).diff(moment(durationEnd));
    const duration = moment.duration(dateDiff);

    return duration.humanize(true);
  },

  dateDiffAge: (durationStart: Date, durationEnd: Date): string => {
    if(isZeroDate(durationStart) || isZeroDate(durationEnd)) {
      return `N/A`;
    }

    const dateDiff = moment(durationStart).diff(moment(durationEnd));
    const duration = moment.duration(dateDiff);

    return duration.humanize(false) + ` old`;
  },

  duration: (secs: number): string => {
    if(secs === 0) {
      return `N/A`;
    }

    if (secs >= 3600 * 24) {
      const fullDays = Math.floor(secs / (3600 * 24));
      return moment.unix(secs).format(`${fullDays}[d] H[h] m[m] s[s]`);
    } else if (secs >= 3600) {
      const duration = moment.duration(secs, `seconds`);
      return `${duration.hours()}h ${duration.minutes()}m ${duration.seconds()}s`;
    } else if (secs >= 60) {
      return moment.unix(secs).format(`m[m] s[s]`);
    } else {
      return moment.unix(secs).format(`s[s]`);
    }
  },

  percentage: (percentage: number): string => {
    return `${percentage}%`;
  },

  dailyRate: (total: number, days: number): string => {
    if(days == 0 || total == 0) {
      return `N/A`;
    }

    const dailyRate = total / days;

    if (dailyRate <= 1/30) {
      return `< 1/month`;
    }

    if (dailyRate >= 1/30 && dailyRate < 1/7) {
      return `${Math.round(dailyRate * 30)}/month`;
    }

    if (dailyRate >= 1/7 && dailyRate < 5/7) {
      return `${Math.round(dailyRate * 7)}/week`;
    }

    return `${Math.round(dailyRate)}/day`;
  },

  date: (date: Date): string => {
    return moment(date).utc().format(`DD MMM YYYY`);
  },

  dateTime: (date: Date): string => {
    return moment(date).utc().format(`DD MMM YYYY HH:mm:ss`);
  }
};
