class SmsController < ApplicationController
  post "/sms_incoming" do
    # TODO:
    # figure out if the texter is legit
    # assign a number from a pool
    client_number = params['From']
    body = params['Body']
    body.downcase!
    body.strip!
    number_stripped = strip_number(client_number)

    case body
    when 'main'
      if start_calling :main, client_number
        call_edd :main, client_number
      end
    when 'online'
      if start_calling :online, client_number
        call_edd :online, client_number
      end
    when 'done'
      sms client_number, "We will stop calling for you after the current attempt is finished."
      redis.del("active-#{number_stripped}")
    when 'status'
      label = redis.get("active-#{number_stripped}")
      call_count = redis.get("call_count-#{number_stripped}")
      sms client_number, "Currently calling: #{label}\nCalls so far: #{call_count}"
    when 'faq', 'hello'
      sms client_number, "Welcome to EDDbot. Sometimes the California Employment Development Department is so busy you can't even get on hold, so you have to call them over and over all day. This bot does the redialing. When it thinks it's on hold, it will call you back and connect the calls. You still have to wait on hold, though."
    else
      sms client_number, "Unrecognized command. Here is what you can do:\nMAIN - Call EDD's main UI line (8-noon M-F)\nONLINE - Call EDD Online Support (8am-8pm 7days)\nDONE - Stop calling\nSTATUS - See your call stauts\nFAQ - Explain what this is"
    end
  end

  def start_calling label, client_number
    number_stripped = strip_number(client_number)
    active = redis.get("active-#{number_stripped}")
    if active
      sms client_number, "We are already making calls for you right now. Reply with DONE to stop."
      return false
    end

    redis.set("call_count-#{number_stripped}", "0")
    redis.set("active-#{number_stripped}", label.to_s)
    true
  end
end
