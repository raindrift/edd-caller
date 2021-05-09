class SmsController < ApplicationController
  MENU = "Here is what you can do:\nMAIN - Call EDD's main UI line (8-noon M-F)\nONLINE - Call EDD Online Support (8am-8pm 7days)\nDONE - Stop calling\nSTATUS - See what the bot is up to on your behalf\nFAQ - Frequent questions and answers"
  WELCOME = "Welcome to EDDbot. Sometimes the California Employment Development Department is so busy you can't even get on hold, so you have to call them over and over all day. This bot does the redialing. When it thinks it's in the queue, it will call you back and connect the calls. You still have to wait on hold, though.\nTry the online support number first, since it is easier to reach and they can solve most issues.\n#{MENU}"

  post "/incoming_sms" do
    # TODO:
    # figure out if the texter is legit
    # assign a number from a pool
    client_number = params['From']
    body = params['Body']
    body.downcase!
    body.strip!
    number_stripped = strip_number(client_number)

    command, param = body.split(/\s/, 2)

    if ! has_access?(number_stripped)
      sms client_number, "Hi! My name's Ian, and I made this bot for calling California EDD. I built it at the start of the pandemic for my partner when they couldn't get through, and then opened it up to friends and family. Recently, it made its way onto YouTube, and lots of people are trying to use it. It can't handle that kind of demand, so I've had to take it offline for now.\n\nI'm working on a fix so more people can use it. I saved your number, so when it's ready I'll text you and let you know. It could be a while though, since I'm just one person and I'm doing this in my spare time. Thanks for understanding. Good luck, and you'll hear from me soon. -Ian"
      redis.incr("rejected_count-#{number_stripped}")
      return
    end

    case command
    when 'main'
      sms client_number, "Right now the 'main' dialer is not working (Sorry! I'll fix it soon!). But the 'online' option should get you someone who can help. Try it instead?"
      # if start_calling :main, client_number
      #   call_edd :main, client_number
      # end
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
      sms client_number, "1/5 Do I have to wait on hold?\nYes. The bot just does the redialing to get you into the hold queue in the first place."
      sms client_number, "2/5 Does this get me a human?\nYes. The bot navigates the voicemail tree to find you a human."
      sms client_number, "3/5 Which number should I call?\nONLINE: \"Get help with general UI questions and technical help with registration, password resets, EDD Account Numbers, and how to use UI Online.\"\nMAIN: \"Get help with filing a claim by phone or getting payment information.\""
      sms client_number, "4/5 Can EDD call me back?\nFor the MAIN number, sometimes. But make sure to enter a callback number manually. The one they auto-detect will be wrong."
      sms client_number, "5/5 Who made this? What if I have issues?\nHi! I'm Ian. Text me at 415-240-8408."
    when 'hello'
      sms client_number, WELCOME
    when 'add'
      if number_stripped != "14152408408"
        sms client_number, "Unrecognized command.\n#{MENU}"
        return
      end

      new_number = normalize_number(param)
      new_number_stripped = strip_number(new_number)
      if !valid_us_pots_number?(new_number)
        sms client_number, "Malformed number"
        return
      end

      redis.set("call_count-#{new_number_stripped}", "0")
      sms client_number, "Added #{new_number_stripped}"
      sms new_number, WELCOME
    else
      sms client_number, "Unrecognized command.\n#{MENU}"
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
    sms "+14152408408", "Calling started for #{number_stripped} / #{label}" # janky monitoring
    return true
  end

  def has_access? number_stripped
    return !! redis.get("call_count-#{number_stripped}")
  end
end
