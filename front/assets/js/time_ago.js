class TimeAgo extends HTMLElement {
    constructor() {
        super();
        this.datetime = this.getAttribute("datetime");
        this.locale = this.getAttribute("locale") || "en"; // Default locale: English
        this.updateTime = this.updateTime.bind(this);
    }

    connectedCallback() {
        this.updateTime();
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

    decorateRelative(date) {
        const now = new Date();
        const diffInSeconds = Math.floor((now - date) / 1000);
        const diffInHours = Math.floor(diffInSeconds / 3600);
        const daysDifference = Math.floor(diffInSeconds / 86400);

        if (diffInHours >= 1) return this.formatDateWithTime(date);
        return this.formatRelativeTime(diffInSeconds);
    }

    formatRelativeTime(seconds) {
        const rtf = new Intl.RelativeTimeFormat(this.locale, { numeric: "auto" });

        if (Math.abs(seconds) < 60) return rtf.format(-seconds, "second");
        if (Math.abs(seconds) < 3600) return rtf.format(-Math.floor(seconds / 60), "minute");
        return rtf.format(-Math.floor(seconds / 3600), "hour");
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
