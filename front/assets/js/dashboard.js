import $ from "jquery"; // live on click event

import { GoogleCharts } from 'google-charts';
import { IntervalSelector } from './dashboard/interval_selector'

export var Dashboard = {
  initOptions: function() {
    this.options = {
      chart_opt: {
        type: 'line',
        height: 300,
        colors: ["#313DA2"],
        axisOptions: {
          xIsSeries: true,
          xAxisMode: 'tick'
        },
        lineOptions: {
          hideDots: 1,
          regionFill: 1
        }
      },
      startPicker: null,
      endPicker: null
    }
  },
  init: function() {
    this.initOptions()

    this.intervalSelector = new IntervalSelector()

    for (let el of document.getElementsByClassName("x-chart")) {
      this.fetch_retry(el.dataset.chartHref, {credentials: 'same-origin'}, 5)
      .then(this.parseJson.bind(this))
      .then(function(data) {
        this.draw_chart(el, data);
      }.bind(this))
      .catch(function(reason) {
        console.log(reason);
      });
    }

    $(".widget-container").on("click", ".pollman-links a", function(event) {
      event.preventDefault();

      Pollman.stop();

      var node = $(event.target).parents('.pollman-container')[0];
      node.setAttribute("data-poll-param-page", event.target.getAttribute('data-page'));

      Pollman.fetchAndReplace(node);

      Pollman.start();
    });
  },
  draw_chart: function(el, data) {
    GoogleCharts.load(function() {
      var sampels = data.date.length;
      var lines = data.names.length;
      var a = [];
      var i;
      var j;
      for (i = 0; i < sampels; i++) {
        var date = data.date[i];
        date = new Date(date*1000);
        a[i] = [date]

        for(j = 0; j < lines; j++) {
          a[i].push(data.values[j][i]);
        }
      }

      var table = new GoogleCharts.api.visualization.DataTable();

      table.addColumn('date', 'Day');
      for(i = 0; i < lines; i++) {
        table.addColumn('number', data.names[i]);
      }

      table.addRows(a);

      var options = {
        curveType: 'function',
        legend: { position: 'none' },
        hAxis: { title: '', format: 'MMM d' },
        vAxis: { viewWindow: { min: 0 } }
      };

      var chart = new GoogleCharts.api.charts.Line(el);
      options = GoogleCharts.api.charts.Line.convertOptions(options);
      chart.draw(table, options);
    }, { 'packages': ['line']});
  },
  fetch_retry: function(url, options, n) {
    return fetch(url, options).catch(function(error) {
      if (n === 1) throw error;
      return this.fetch_retry(url, options, n - 1);
    });
  },
  isJsonResponse: function(response) {
    var contentType = response.headers.get("content-type");
    return contentType && contentType.includes("application/json")
  },
  parseJson: function(response) {
    if (this.isJsonResponse(response)) {
      return response.json();
    } else {
      throw new Error(response.statusText);
    }
  }
}
