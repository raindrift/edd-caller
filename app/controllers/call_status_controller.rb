class CallStatusController < ApplicationController

  post "/call_status/:label" do
    sid = params['CallSid']
    client_number = redis.get("caller-#{sid}")
    number_stripped = strip_number(client_number)
    label = params['label'].to_sym
    call_count = redis.get("call_count-#{strip_number(client_number)}")

    if after_hours? label
      sms client_number, "The number we were calling is now closed. Try again soon? #{call_count_report(client_number)}"
      redis.lpush("failures-#{label}", "#{Time.now.strftime('%Y%m%d%H%M%S')}:#{call_count}")
      sms "+14152408408", "Failed after hours for #{number_stripped} / #{label} / #{call_count} calls" # janky monitoring
      return
    end

    active = redis.get("active-#{number_stripped}")
    if not active
      sms client_number, call_count_report(client_number)
      sms "+14152408408", "Success for #{number_stripped} / #{label} / #{call_count} calls" # janky monitoring
      return
    end

    # time it takes to call plus one minute of hold time
    if label == :main
      max_retry_duration = 282
    else
      max_retry_duration = 209
    end

    if params['CallDuration'].to_i < max_retry_duration
      call_edd label, client_number, false
    else
      sms client_number, "Looks like maybe you got through? We'll stop trying, but you can restart any time (reply with MAIN or ONLINE). #{call_count_report(client_number)}"
      redis.lpush("successes-#{label}", "#{Time.now.strftime('%Y%m%d%H%M%S')}:#{call_count}")
      redis.del("active-#{number_stripped}")
      sms "+14152408408", "Success for #{number_stripped} / #{label} / #{call_count} calls / #{params['Duration']} min" # janky monitoring
    end
  end
end
