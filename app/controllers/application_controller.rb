require './config/environment'
require 'twilio-ruby'
require "redis"
require "mock_redis"

class ApplicationController < Sinatra::Base

  def initialize(*args)
    super(*args)

    @redis = connect_redis
    @twilio = connect_twilio
  end

  attr_reader :twilio, :redis

  configure do
    set :public_folder, 'public'
    set :views, 'app/views'
  end

  get "/" do
    erb :welcome
  end

  def connect_redis
    if ENV['SINATRA_ENV'] == 'test'
      MockRedis.new
    elsif ENV['SINATRA_ENV'] == 'production'
      Redis.new(url: ENV['REDIS_URL'])
    else
      Redis.new
    end
  end

  def connect_twilio
    if ENV['SINATRA_ENV'] == 'test'
      account_sid = 'twilio-sid'
      auth_token = 'twilio-token'
    else
      account_sid = ENV['TWILIO_ACCOUNT_SID']
      auth_token = ENV['TWILIO_AUTH_TOKEN']
    end
    Twilio::REST::Client.new(account_sid, auth_token)
  end

  def sms number, message
    twilio.messages.create(
      body: message,
      from: ENV.fetch('MAIN_NUMBER'),
      to: number,
    )
  end

  def call_edd label, client_number
    main_number = ENV.fetch('MAIN_NUMBER')

    if label == :main
      edd_number = '+18003005616'
      pretty_number = 'EDD main (800-300-5616)'
      uri = "call_main/#{strip_number(client_number)}"
    else
      edd_number = '+18339782511'
      pretty_number = 'EDD Online Support (833-978-2511)'
      uri = "call_online/#{strip_number(client_number)}"
    end

    call = twilio.calls.create(
      url: "#{ENV.fetch('URL')}/#{uri}",
      status_callback: "#{ENV.fetch('URL')}/call_status/#{label.to_s}",
      to: edd_number,
      from: ENV.fetch('MAIN_NUMBER'), # TODO: fetch a number from a pool
    )

    redis.set("current_call-#{strip_number(client_number)}", call.sid)
    redis.set("caller-#{call.sid}", client_number, ex: 60 * 60 * 4) # TTL 4 hours
    redis.incr("call_count-#{strip_number(client_number)}")

    sms client_number, "Calling #{pretty_number}. Expect a call from #{main_number}. Reply with DONE to stop calling.\n"

    if label == :main
      sms client_number, "If you're offered the option to get a call back, choose the option to manually enter your phone number. The number they detect will be wrong. They're good about calling back, but the call can come hours after they close (at noon)."
    end
  end

  def call_count_report client_number
    call_count = redis.get("call_count-#{strip_number(client_number)}")
    return "We made #{call_count} calls for you this time."
  end
end
