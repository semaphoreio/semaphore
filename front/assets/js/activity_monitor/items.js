import $ from "jquery"
import _ from "lodash"

import { Http } from "./../http"
import { Item } from "./items/item"

export class Items {
  constructor(selector, data) {
    this.el = $(selector)
    this.data = {}

    this.lobby = this.initLobby()
    this.el.append(this.lobby)

    this.active = this.initActive()
    this.el.append(this.active)

    this.empty = this.initEmpty()
    this.el.append(this.empty)
    this.empty.hide()

    this.handleStop()

    this.pauseUpdates = false

    this.update(data)
  }

  initLobby() {
    return $(`
      <details class="mt4 mb3">
        <summary class="pointer">Lobby (<span id="activity_monitor_lobby_counter">0</span>) · Pipelines waiting for previous pipelines in their branch, pull request and delivery queue</summary>
        <div id="activity_monitor_lobby_items"></div>
      </details>
    `)
  }

  initActive() {
    return $(`<div>
      <div id="activity_monitor_active_items">
      </div>
    </div>`)
  }

  initEmpty() {
    let assets_path = $("meta[name='assets-path']").attr("content")

    return $(`
      <div class="tc mv5 mv6-ns">
        <img src="${assets_path}/images/ill-curious-girl.svg">
        <h4 class="f4 mt2 mb0">It's quiet your projects right now</h4>
        <p class="mb0 measure center">Push to repository to trigger a workflow</p>
      </div>
    `)
  }

  handleStop() {
    $(this.el).on("click", "[data-action=activity-monitor-stop]", (e) => {
      this.pauseUpdates = true
      let element = $(e.currentTarget)

      element.parent().hide()
      element.parent().parent().find("[data-stop=are-you-sure-dialog]").show()
    })

    $(this.el).on("click", "[data-action=activity-monitor-stop-nevermind]", (e) => {
      this.pauseUpdates = false
      let element = $(e.currentTarget)

      element.parent().hide()
      element.parent().parent().find("[data-stop=stop]").show()
    })

    $(this.el).on("click", "[data-action=activity-monitor-stop-execute]", (e) => {
      let element = $(e.currentTarget)

      let endpoint = element.attr("data-endpoint")
      let itemType = element.attr("data-item-type")
      let itemID = element.attr("data-item-id")

      element.parent().hide()
      element.parent().parent().find("[data-stop=stopping]").show()

      Http.postJson(endpoint, {item_type: itemType, item_id: itemID}, () => {
        this.pauseUpdates = false
        this.update()
      })
    })
  }

  update(newData) {
    if(this.pauseUpdates) return;
    if(_.isEqual(this.data, newData)) return;
    this.data = newData

    let nonVisible = newData.waiting.non_visible_job_count + newData.running.non_visible_job_count
    let lobbyItems = this.data.lobby.items
    let activeItems = _.concat(newData.waiting.items, newData.running.items)

    if(this.data.lobby.items.length > 0) {
      this.lobby.show()
      this.lobby.find("#activity_monitor_lobby_counter").text(this.data.lobby.items.length)
      this.lobby.find("#activity_monitor_lobby_items").html(lobbyItems.map(item => Item.render(item, "lobby")).join("\n"))
    } else {
      this.lobby.hide()
    }

    if(activeItems.length > 0 || nonVisible > 0) {
      this.active.show()

      let items = activeItems.map(item => Item.render(item, "active")).join("\n")
      let hidden = Item.hidden(nonVisible)

      this.active.find("#activity_monitor_active_items").html(items + hidden)
    }

    if(this.data.lobby.items.length === 0 && activeItems.length === 0 && nonVisible === 0) {
      this.active.hide()
      this.empty.show()
    }
  }

}
