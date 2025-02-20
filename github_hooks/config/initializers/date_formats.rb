# http://api.rubyonrails.org/classes/Date.html#method-i-to_formatted_s
Date::DATE_FORMATS[:short_ordinal] = ->(date) { date.strftime("%B #{date.day.ordinalize}") }
Date::DATE_FORMATS[:full_month_and_day] = ->(date) { date.strftime("%B %e") }
Date::DATE_FORMATS[:full_weekday_full_month_and_day] = ->(date) { date.strftime("%A, %B %e") }
