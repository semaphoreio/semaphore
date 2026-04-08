import $ from "jquery";
import _ from "lodash";
import { Layout } from "../layout"
import { Timer } from "../workflow_view/timer"
import { Favicon } from "../favicon"
import { State } from "./state"
import { Live } from "./live"
import { Scroll } from "./scroll"
import { Highlight } from "./highlight"
import { FoldToggle } from "./fold_toggle"
import { Settings } from "./components/settings"
import { Container } from "./components/container"
import { Jumps } from "./components/jumps"
import { LiveSettings } from "./components/live_settings"
import { EventsFetcher } from "./events_fetcher"
import { Render } from "./render"
import { SleepDetector } from "../sleep_detector"

export class JobLogs {
  static init() {
    let config = {
      artifactLogsURL: InjectedDataByBackend.ArtifactLogsURL,
      isJobFinished: InjectedDataByBackend.FinishedJob,
      logState: InjectedDataByBackend.LogState,
      eventsPath: InjectedDataByBackend.EventsPath,
      eventsToken: InjectedDataByBackend.EventsToken
    }

    return new JobLogs(config)
  }

  constructor(config) {
    this.slept = false
    this.config = config
    this.startTime = performance.now();
    this.metricTags = [];

    State.init(config.logState)

    SleepDetector.init(() => {
      this.slept = true
    })

    this.setUpComponents()
    this.start()
  }

  start() {
    if (State.get("state") == "pending") {
      setTimeout(this.start.bind(this), 5000)
      return
    }

    if (!this.config.artifactLogsURL) {
      if(State.get("fetching") == "ready") {
        this.startLogs()
      }

      return
    }

    fetch(this.config.artifactLogsURL, {method: "HEAD"})
      .then(response => {
        if(response.ok) {
          State.set("trimmed_logs", true)
          return
        }

        switch(response.status) {
          case 404:
            throw new Error("Artifact for logs does not exist")
          default:
            throw new Error(`Unexpected response status: ${response.status}`);
        }
      })
      .catch(error => {
        if(State.get("fetching") == "ready") {
          this.startLogs()
        }
      })
  }

  setUpComponents() {
    let divs = {
      logs: "#job-log-container",
      settings: "#job-log-settings",
      liveSettings: "#job-log-live-settings",
      jumps: "#job-log-jump"
    }

    new Layout.MaxHeight(divs.logs, 50, 800)
    Timer.init();

    this.components = {
      settings: new Settings(this, divs.settings),
      container: new Container(this, divs.logs),
      jumps: new Jumps(this, divs.jumps, divs.logs),
      liveSettings: new LiveSettings(this, divs.liveSettings)
    }

    State.onUpdate(this.update.bind(this))

    if(this.config.isJobFinished == false) {
      Live.init(divs.logs)
    }
    Highlight.init(divs.logs)
    Favicon.replace(State.get("state"))

    this.update()

    this.on("click", ".job-log-line.command", (e) => {
      const fold = e.target.closest(".job-log-fold")

      if (FoldToggle.isTogglable(fold)) {
        FoldToggle.toggle(fold)
      }
    })

    this.on("click", ".job-log-line-number", (e) => {
      const line = e.target.closest('.job-log-line');
      Highlight.highlightLine(line, event.shiftKey)

      e.stopPropagation()
    })
  }

  setupFoldExpandButtons() {
    this.configureExpandsButton()

    this.on("click", ".job-log-line-expand", (e) => {
      const fold = e.target.closest(".job-log-fold");
      const jobCommand = fold.querySelector('.job-log-line.command')
      this.toggleExpandCommand(e.target, jobCommand)
    })
  }

  toggleExpandCommand(expandButton, jobCommand) {
    if (jobCommand.style.maxHeight) {
      this.collapseCommand(expandButton, jobCommand)
    } else {
      this.expandCommand(expandButton, jobCommand)
    }
  }

  expandCommand(expandButton, jobCommand) {
    jobCommand.style.maxHeight = "none"
    expandButton.innerText = "↑ Collapse ↑"
    expandButton.style.top = jobCommand.offsetHeight.toString() + "px"
  }

  collapseCommand(expandButton, jobCommand) {
    jobCommand.style.maxHeight = ""
    expandButton.innerText = "↓ Expand ↓"
    expandButton.style.top = jobCommand.offsetHeight.toString() + "px"
  }

  configureExpandsButton() {
    if (State.get("sticky")) {
      this.enableExpandsButton()
    } else {
      this.disableExpandsButton()
    }
  }

  enableExpandsButton() {
    document.querySelectorAll('.job-log-line.command').forEach((element) => {
      const fold = element.closest(".job-log-fold");
      const expandButton = fold?.querySelector(".job-log-line-expand");
        
      if (element.offsetHeight >= 250) {
        expandButton.style.top = element.offsetHeight.toString() + "px"
        expandButton?.classList.remove("dn");
      } else {
        expandButton?.classList.add("dn");
      }
    });
  }

  disableExpandsButton() {
    document.querySelectorAll('.job-log-line.command').forEach((element) => {
      const fold = element.closest(".job-log-fold");
      const expandButton = fold?.querySelector(".job-log-line-expand");
        
      expandButton?.classList.add("dn");
    });
  }

  update() {
    _.forIn(this.components, (component) => component.update())
    this.configureExpandsButton()
  }

  on(event, selector, callback) {
    console.log(`Registering event: '${event}', target: '${selector}'`)

    $("body").on(event, selector, (e) => {
      console.log(`Event for '${event}' on ${selector} started`)
      let result = callback(e)
      console.log(`Event for '${event}' on ${selector} finished`)

      return result
    })
  }

  startLogs() {
    this.startFetchingEvents()
    this.startRenderLines()
  }

  startFetchingEvents() {
    let url = this.config.eventsPath
    let token = this.config.eventsToken
    EventsFetcher.init({url: url, token: token, maxConsecutiveErrors: 7, backOffInterval: 5000, regularInterval: 200})
    EventsFetcher.tick()
  }

  startParsingEvents() {
    EventsParser.init()
    EventsParser.onFinish(() => {})
  }

  startRenderLines() {
    Render.start({div: "#job-log", metricTags: [], isJobFinished: this.config.isJobFinished})
    Render.onFinish(() => {
      if(this.config.isJobFinished === true) {
        this.logRenderDuration(this.startTime, performance.now(), "v2");
        this.scrollToLastOpenFold();
        this.setupFoldExpandButtons()
      }
    })
  }

  logRenderDuration(start, end, version) {
    console.log(`Job logs rendering ${version} took ${(end - start) / 1000} seconds`);
  }

  scrollToLastOpenFold() {
    let element = document.querySelector(".job-log-fold.open .job-log-line:last-child")
    if(element) {
      let container = document.querySelector("#job-log-container")
      Scroll.to(container, element)
    }
  }

  updateJobState(newState) {
    State.set("state", newState)
    Favicon.replace(State.get("state"))

    if(newState != "running") {
      let container = document.querySelector("#job-log-container")
      Scroll.bottom(container)
    }
  }
}
