export default function reRenderPage(html) {
  document.body.innerHTML = html; 

  // script for hiding the notification and error popup
  let close_notification_btn = document.getElementById("hide-notification");
  if(close_notification_btn){
    close_notification_btn.onclick = function(event) {
      event.preventDefault();
      const elem = document.getElementById("changes-notification");
      elem.style.display = "none";
    }
  }

  let close_alert_btn = document.getElementById("hide-alert");
  if(close_alert_btn){
    close_alert_btn.onclick = function(event) {
      event.preventDefault();
      const elem = document.getElementById("changes-alert");
      elem.style.display = "none";
    }
  }
}
