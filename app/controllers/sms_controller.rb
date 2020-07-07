class SmsController < ApplicationController
  post "/incoming_sms" do
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
      sms client_number, "Currently calling: #{label || 'not calling'}\nCalls so far: #{call_count || 0}"
    when 'faq'
      sms client_number, "1/4 Do I have to wait on hold?\nYes. The bot just does the redialing to get you into the hold queue in the first place."
      sms client_number, "2/4 Does this get me a human?\nYes. The bot navigates the voicemail tree to find you a human."
      sms client_number, "3/4 Which number should I call?\nONLINE: \"Get help with general UI questions and technical help with registration, password resets, EDD Account Numbers, and how to use UI Online.\"\nMAIN: \"Get help with filing a claim by phone or getting payment information.\""
      sms client_number, "4/4 Can EDD call me back?\nFor the MAIN number, sometimes. But make sure to enter a number manually. The one they auto-detect will be wrong."
    when 'hello'
      sms client_number, "Welcome to EDDbot. Sometimes the California Employment Development Department is so busy you can't even get on hold, so you have to call them over and over all day. This bot does the redialing. When it thinks it's on hold, it will call you back and connect the calls. You still have to wait on hold, though."
    else
      sms client_number, "Unrecognized command. Here is what you can do:\nMAIN - Call EDD's main UI line (8-noon M-F)\nONLINE - Call EDD Online Support (8am-8pm 7days)\nDONE - Stop calling\nSTATUS - See your call stauts\nFAQ - Explain what this is"
    end
  end

  def start_calling label, client_number
    if after_hours? label
      sms client_number, "That line is closed right now. Main is 8am-noon M-F, and Online Support is 8am-8pm 7 days (Pacific time)"
      return false
    end
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
