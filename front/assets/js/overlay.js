export class Overlay {
  static init() {
    window.addEventListener('click', function (event) {
      const dataAction = event.target.getAttribute('data-action')
      const overlayId = event.target.getAttribute('data-overlay-id')

      switch (dataAction) {
        case 'open-overlay':
          event.preventDefault()
          Overlay.open(overlayId)
          return;
        case 'close-overlay':
          event.preventDefault()
          Overlay.close()
          return;
        default:
          return;
      }
    })
  }

  static open(overlayId) {
    const overlay = document.getElementById('overlay')
    const overlayContent = document.getElementById(overlayId)
    if (!overlay || !overlayContent) { return; }

    overlay.innerHTML = overlayContent.innerHTML
    overlay.style.display = 'block'
  }

  static close() {
    const overlay = document.getElementById('overlay')
    if (!overlay) { return; }

    overlay.style.display = 'none'
    overlay.innerHTML = ''
  }
}
