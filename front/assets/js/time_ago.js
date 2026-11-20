const EXACT_FORMAT_OPTIONS = {
    weekday: "short",
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
    timeZoneName: "short",
};

// Building an Intl formatter is two orders of magnitude dearer than using one, and
// pages can carry dozens of these, so keep one per locale for the life of the page.
const exactFormatters = new Map();

function exactFormatter(locale) {
    const key = locale || "";

    if (!exactFormatters.has(key)) {
        exactFormatters.set(key, new Intl.DateTimeFormat(locale, EXACT_FORMAT_OPTIONS));
    }

    return exactFormatters.get(key);
}

export class TimeAgo extends HTMLElement {
    constructor() {
        super();
        this.datetime = this.getAttribute("datetime");
        this.locale = this.getAttribute("locale") || "en"; // Default locale: English
        // Undefined rather than "en": an exact timestamp is only unambiguous in the
        // reader's own conventions. The relative text above keeps the "en" default
        // because formatDateWithTime parses English token order back out of its output.
        this.exactLocale = this.getAttribute("locale") || undefined;
        this.updateTime = this.updateTime.bind(this);
    }

    connectedCallback() {
        // Visible text first: the tooltip is an enhancement, and it must not be able
        // to stop the relative time rendering or the interval being installed.
        this.updateTime();
        this.setExactTitle();
        this.interval = setInterval(this.updateTime, 1000);
    }

    disconnectedCallback() {
        clearInterval(this.interval);
    }

    updateTime() {
        if (!this.datetime) {
            this.textContent = "";
            return;
        }

        const date = new Date(this.datetime);
        if (isNaN(date)) {
            this.textContent = "Invalid date";
            return;
        }

        this.textContent = this.decorateRelative(date);
    }

    // The visible text is relative ("31 minutes ago"), which reads well but makes
    // you do the arithmetic to get a wall-clock time. Keep the exact timestamp one
    // hover away rather than making people work it out. `datetime` is immutable, so
    // this runs once on connect rather than on every tick of the relative-time timer.
    setExactTitle() {
        if (!this.datetime) return;

        const date = new Date(this.datetime);
        if (isNaN(date)) return;

        this.title = this.formatExact(date);
    }

    formatExact(date) {
        return exactFormatter(this.exactLocale).format(date);
    }

    decorateRelative(date) {
        const now = new Date();
        const diffInSeconds = Math.floor((now - date) / 1000);
        const diffInHours = Math.floor(diffInSeconds / 3600);
        const alwaysRelative = this.hasAttribute("always-relative");

        if (diffInHours >= 1 && !alwaysRelative) return this.formatDateWithTime(date);
        return this.formatRelativeTime(diffInSeconds, alwaysRelative);
    }

    formatRelativeTime(seconds, longUnits) {
        const rtf = new Intl.RelativeTimeFormat(this.locale, { numeric: "auto" });
        const day = 86400;

        if (Math.abs(seconds) < 60) return rtf.format(-seconds, "second");
        if (Math.abs(seconds) < 3600) return rtf.format(-Math.floor(seconds / 60), "minute");
        if (Math.abs(seconds) < day || !longUnits) return rtf.format(-Math.floor(seconds / 3600), "hour");
        if (Math.abs(seconds) < 30 * day) return rtf.format(-Math.floor(seconds / day), "day");
        if (Math.abs(seconds) < 365 * day) return rtf.format(-Math.floor(seconds / (30 * day)), "month");
        return rtf.format(-Math.floor(seconds / (365 * day)), "year");
    }

    formatDateWithTime(date) {
        const options = { weekday: "short", day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit", hour12: false };
        const formattedDate = date.toLocaleDateString(this.locale, options);
        const time = date.toLocaleTimeString(this.locale, { hour: "2-digit", minute: "2-digit", hour12: false });
        
        const [weekday, month, day, year] = formattedDate.replaceAll(",", "").split(" ");
        const suffixedDay = day + this.ordinalSuffix(parseInt(day, 10));
        
        return `${weekday} ${suffixedDay} ${month} ${year} at ${time}`;
    }

    ordinalSuffix(day) {
        if ([11, 12, 13].includes(day)) return "th";
        switch (day % 10) {
            case 1: return "st";
            case 2: return "nd";
            case 3: return "rd";
            default: return "th";
        }
    }
}

export function defineTimeAgoElement() {
    !customElements.get('time-ago') && customElements.define("time-ago", TimeAgo);
}
