class CallStatusController < ApplicationController

  post "/call_status/:label" do
    sid = params['CallSid']
    client_number = redis.get("caller-#{sid}")
    number_stripped = strip_number(client_number)
    label = params['label'].to_sym

    if label == :main
      max_retry_duration = 170
    else
      max_retry_duration = 40
    end

    # TODO: check after hours & user finished here

    active = redis.get("active-#{number_stripped}")
    if not active
      sms client_number, call_count_report(client_number)
      return
    end

    if params['Duration'].to_i < max_retry_duration
      call_edd label, client_number
    else
      sms client_number, "Looks like maybe you got through? We'll stop trying, but you can restart any time (reply with MAIN or ONLINE). #{call_count_report(client_number)}"
      call_count = redis.get("call_count-#{strip_number(client_number)}")
      redis.lpush("successes-#{label}", "#{Time.now.strftime('%Y%m%d%H%M%S')}:#{call_count}")
    end
  end
end
