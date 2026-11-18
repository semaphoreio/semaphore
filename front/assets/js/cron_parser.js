import cronstrue from 'cronstrue';

import {parseExpression} from 'cron-parser'

export var CronParser = {
  init: function() {
    var next = document.querySelectorAll("[cron-next]");
    var when = document.querySelectorAll("[cron-when]");

    Array.from(next).forEach(function(cron) {
      CronParser.next(cron);
    });
    Array.from(when).forEach(function(cron) {
      CronParser.when(cron);
    });
  },

  when: function(cron) {
    try {
    if (!cron || !cron.hasAttribute("cron-when")) return;

    var expression = cron.getAttribute('expression');

    cron.textContent = cronstrue.toString(expression, { verbose: true });
    } catch (err) {
      cron.textContent = err
    }
  },

  next: function(cron) {
    if (!cron || !cron.hasAttribute("cron-next")) return;

    var expression = cron.getAttribute('expression');
    var options = {tz: 'utc'};
    var interval = parseExpression(expression, options)

    cron.textContent = interval.next()._date.format('YYYY-MM-DD HH:mm:ss [UTC]');
  }
};
