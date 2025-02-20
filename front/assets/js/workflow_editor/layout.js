import $ from "jquery";

export class Layout {
  //
  // Handles the layout of the workflow editor.
  //
  // 1. Diagram uses the whole height available in the window
  // 2. ConfigPanel uses the whole height available in the window
  // 3. The width of the diagram/config panel can be adjusted
  //
  // On every window resize, the layout is recalculated.
  //

  static handle(diagramSelector, configPanelSelector) {
    return new Layout(diagramSelector, configPanelSelector)
  }

  constructor(diagramSelector, configPanelSelector) {
    this.diagramSelector = diagramSelector
    this.configPanelSelector = configPanelSelector
    this.outputDivContentSelector = "#workflow-editor-config-panel-content"

    this.diagram = $(this.diagramSelector)
    this.config  = $(this.configPanelSelector)

    this.handleConfigPanelResize()

    // initial set up of diagram size
    this.update()

    // update sizes on window size change
    $(window).on("resize", this.update.bind(this))

    // periodically check and redraw
    setInterval(() => {
      this.update()
    }, 5000)
  }

  update() {
    let paddingBottom = 18;

    // Diagram
    let height = $(window).height() - this.diagram.parent().offset().top
    let width = $(window).width() - this.config.width()

    this.diagram.css({"height": height - paddingBottom + "px", "width": width + "px"})

    // Config
    let panel = $(this.configPanelSelector)
    let panelHeight = $(window).height() - panel.parent().offset().top

    let css = {"height": panelHeight - paddingBottom + "px"}

    panel.css(css)
    panel.find(this.outputDivContentSelector).css(css)
  }

  handleConfigPanelResize() {
    let startCursor = null;

    let mouseMoveHandler = (e) => {
      e.preventDefault()

      let newWidth = $(window).width() - e.pageX

      if(newWidth < 200) { newWidth = 200 }
      if(newWidth > 1200) { newWidth = 1200 }

      this.config.width(newWidth)

      //
      // The update needs to be a called with a slight delay to avoid a weird
      // diagram jerking effect .
      //
      setTimeout(() => { this.update() }, 10)
    }

    let mouseUpHandler = () => {
      document.removeEventListener("mousemove", mouseMoveHandler)
      document.removeEventListener("mouseup", mouseUpHandler)

      document.body.style.cursor = startCursor
    }

    this.config.on("mousedown", "[data-resize]", (e) => {
      e.preventDefault();

      startCursor = document.body.style.cursor
      document.body.style.cursor = "col-resize"

      document.addEventListener("mousemove", mouseMoveHandler)
      document.addEventListener("mouseup", mouseUpHandler)
    })
  }

}
