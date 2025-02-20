import $ from "jquery"

export default function() {
  let assets_path = $("meta[name='assets-path']").attr("content")

  return `
    <div class="tc pt5">
      <img src="${assets_path}/images/ill-editor-mono.svg" alt="girl with boxes">
      <p class="f5 tc ph4 mv3">Choose the pipeline or pipeline block that you want to edit on the left.<br>←</p>
    </div>
  `
}
