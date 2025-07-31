import $ from "jquery"; // live on click event

import pikaday from 'pikaday';
import querystringify from 'querystringify';

export class IntervalSelector {
  constructor() {
    this.dropdown = document.querySelector('#datePicker')

    this.startPicker = new pikaday({
      field: this.dropdown.querySelector('#pikadayInputStart'),
      minDate: new Date(2018, 10, 31),
      maxDate: new Date(),
      onSelect: this.handleStartDateChange.bind(this)
    })

    this.endPicker = new pikaday({
      field: this.dropdown.querySelector('#pikadayInputEnd'),
      minDate: new Date(2018, 10, 31),
      maxDate: new Date(),
      onSelect: this.handleEndDateChange.bind(this)
    })

    this.tippy = tippy('.date-picker-trigger', {
      content: this.dropdown,
      popperOptions: {
        strategy: 'fixed'
      },
      allowHTML: true,
      trigger: 'click',
      theme: 'dropdown',
      interactive: true,
      placement: 'bottom-end',
      duration: [100,50],
      maxWidth: '640px',
      onShow: this.onShow.bind(this),
      hideOnClick: 'toggle'
    })

    this.handleIntervalClicked()
    this.handleCustomRangeSet()
    this.handleCustomRangeCancel()
  }

  onShow() {
    this.dropdown.hidden = false
  }

  handleIntervalClicked() {
    $("body").on("click", ".x-dashboard-date-picker", (e) => {
      e.preventDefault();

      var from = e.target.getAttribute('data-range-from')
      var to =  e.target.getAttribute('data-range-to')

      this.redirectTo(from, to)
    })
  }

  handleCustomRangeSet() {
    $("body").on("click", ".x-dashboard-custom-range-set", (e) => {
      e.preventDefault()

      let from = this.dateToString(this.startPicker.getDate())
      let to = this.dateToString(this.endPicker.getDate())

      this.redirectTo(from, to)
    })
  }

  handleCustomRangeCancel() {
    $("body").on("click", ".x-dashboard-custom-range-cancel", (e) => {
      e.preventDefault()

      this.tippy[0].hide()
    })
  }

  handleStartDateChange(date) {
    this.startPicker.setStartRange(date)
    this.endPicker.setStartRange(date)
    this.endPicker.setMinDate(date)
  }

  handleEndDateChange(date) {
    this.startPicker.setEndRange(date)
    this.startPicker.setMaxDate(date)
    this.endPicker.setEndRange(date)
  }

  dateToString(d) {
    return `${d.getFullYear()}-${('00' + (d.getMonth() + 1)).slice(-2)}-${('00' + d.getDate()).slice(-2)}`
  }

  redirectTo(from, to) {
    let query = querystringify.parse(window.location.search)

    query.from = from
    query.to = to

    window.location = querystringify.stringify(query, true)
  }
}
