# Download the helper library from https://www.twilio.com/docs/ruby/install
require 'rubygems'
require 'twilio-ruby'
require 'pry'
require 'dotenv'

Dotenv.load

account_sid = ENV.fetch('TWILIO_ACCOUNT_SID')
auth_token = ENV.fetch('TWILIO_AUTH_TOKEN')
client = Twilio::REST::Client.new(account_sid, auth_token)

to = ARGV[0]

edd_main_tree = "https://f1d45a2d190e.ngrok.io/call_main/#{to}"

while true
  call = client.calls.create(
    # url: edd_online_tree,
    # to: '+18339782511', # edd online
    url: edd_main_tree,
    to: '+18003005616', # edd main
    # to: '+14152408408', # edd main
    from: '+14152235261'
  )


  sid = call.sid
  print "New call, sid: #{sid}\n"

  check_count = 0
  18.times do
    sleep 10
    call = client.calls(sid).fetch
    print "checking status: #{call.status}, checks: #{check_count}\n"

    if check_count > 16
      raise('Long call (answered), exiting')
    end

    if ['completed', 'busy', 'no-answer', 'failed'].include?(call.status)
      break
    end

    if call.status == 'in-progress'
      check_count += 1
    end
  end
end
