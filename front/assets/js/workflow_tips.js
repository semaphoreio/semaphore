import $ from "jquery";

export class WorkflowTips {
  static init() {
    WorkflowTips.handleTipClose()
    WorkflowTips.handleFeedbackButtons()
  }

  static handleTipClose() {
    $("body").on("click", "#workflow-tips-close-popup", function() {
      let projectName = $("#workflow-tips-popup").data("project");

      $("#workflow-tips-popup").html(WorkflowTips.renderFeedbackQuestion())
      document.cookie = `${projectName}-workflow-tip=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`
    });
  }

  static handleFeedbackButtons() {
    $("body").on("click", "[workflow-tips-feedback-button]", function() {
      $("#workflow-tips-popup").html(WorkflowTips.renderThankYouForFeebadk())

      setTimeout(function() { $("#workflow-tips-popup").fadeOut(300); }, 2000);
    });
  }

  static renderFeedbackQuestion() {
    return `
     <div class='bg-washed-green br3 shadow-2 pa3 pa4-ns mh3 mb3'>
       <h3>Were these tips useful to you?</h3>
       <button workflow-tips-feedback-button class='btn btn-secondary'>Yes 🙂</button>
       <button workflow-tips-feedback-button class='btn btn-secondary'>No 😞</button>
     </div>
    `
  }

  static renderThankYouForFeebadk() {
    return `
      <div class='bg-washed-green br3 shadow-2 pa3 pa4-ns mh3 mb3'>
        <p align=center>Thank you for your feedback! 🙌</p
      </div>
    `
  }
}
