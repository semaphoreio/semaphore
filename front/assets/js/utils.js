import moment from "moment";

export class Utils {
  static isBlank(value) {
    return value === undefined || value === null;
  }

  static isNotBlank(value) {
    return !this.isBlank(value);
  }

  static toHHMMSS(numberOfSeconds) {
    let hours = Math.floor(numberOfSeconds / 3600);
    let minutes = Math.floor((numberOfSeconds - (hours * 3600)) / 60);
    let seconds = numberOfSeconds - (hours * 3600) - (minutes * 60);

    if (hours < 10) { hours = "0" + hours }
    if (minutes < 10) { minutes = "0" + minutes }
    if (seconds < 10) { seconds = "0" + seconds }

    if (hours === "00") {
      return `${minutes}:${seconds}`;
    } else {
      return `${hours}:${minutes}:${seconds}`;
    }
  }

  static toHHMMSSTruncated(numberOfSeconds) {
    let hours = Math.floor(numberOfSeconds / 3600);
    let minutes = Math.floor((numberOfSeconds - (hours * 3600)) / 60);
    let seconds = numberOfSeconds - (hours * 3600) - (minutes * 60);
    seconds = Math.trunc(seconds);

    if (hours < 10) { hours = "0" + hours }
    if (minutes < 10) { minutes = "0" + minutes }
    if (seconds < 10) { seconds = "0" + seconds }

    if (hours === "00") {
      return `${minutes}:${seconds}`;
    } else {
      return `${hours}:${minutes}:${seconds}`;
    }
  }

  static toSeconds(nanoseconds) {
    return nanoseconds / 1000000000;
  }

  static dateFromISOWeek(week, year) {
    var date = moment().year(year);
    date.isoWeek(week);
    return date;
  }

  //returns the start of the week: starting monday
  static startOfWeek(date) {
    return moment(date).startOf('isoWeek');
  }

  static endOfWeek(date) {
    return moment(date).endOf('isoWeek');
  }

  // Escapes CSS attribute values
  // Uses CSS.escape() when available, with fallback for older browsers
  // Reference: https://developer.mozilla.org/en-US/docs/Web/API/CSS/escape
  static escapeCSSAttributeValue(value) {
    if (!value) return value;

    // Use native CSS.escape() if available
    if (typeof CSS !== 'undefined' && CSS.escape) {
      return CSS.escape(value);
    }

    // Fallback for older browsers: escape quotes and backslashes
    return value.replace(/(["'\\])/g, '\\$1');
  }
}
