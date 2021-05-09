require 'twilio-ruby'
require 'mock_redis'
require 'tzinfo'
require_relative "spec_helper"

describe SmsController do

  # spy on redis so we can get access to the same instance
  let(:redis) { MockRedis.new }
  before do
    allow_any_instance_of(ApplicationController).to receive(:connect_redis).and_return(redis)
  end

  after do
    Timecop.return
  end

  describe 'incoming_sms' do
    let(:client) do
      double(:client,
        calls: double(:calls, create: double(:call, sid: 'MockCallSid')),
        messages: double(:messages, create: double(:message)),
      )
    end

    before do
      allow(Twilio::REST::Client).to receive(:new).and_return(client)
      allow(ENV).to receive(:fetch).with('URL').and_return('https://app')
      allow(ENV).to receive(:fetch).with('MAIN_NUMBER').and_return('+19998887777')
    end

    context 'with an informational command' do
      it 'responds to hello' do
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /Welcome to EDDbot/)
        post '/incoming_sms', Body: 'hello', From: '+12223334444'
      end

      it 'responds to faq' do
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /Do I have to wait on hold/)
        post '/incoming_sms', Body: 'faq', From: '+12223334444'
      end
    end

    context 'with an unrecognized command' do
      it 'responds with the list of commands' do
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /Unrecognized/)
        post '/incoming_sms', Body: 'foo', From: '+12223334444'
      end
    end

    context 'during business hours' do
      before do
        tz = TZInfo::Timezone.get('US/Pacific')
        now = tz.local_time(2020, 01, 01, 9, 0, 0)
        Timecop.freeze(now)
      end

      xit 'initiates a call to the main number' do
          expect(client.calls).to receive(:create).with(
          url: "https://app/call_main/12223334444",
          to: '+18003005616',  # main
          from: '+19998887777',
          status_callback: 'https://app/call_status/main',
        )

        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /Calling EDD main/)
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /a call back/)
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+14152408408', /Calling started/)

        post '/incoming_sms', Body: 'main', From: '+12223334444'
      end

      it 'initiates a call to online support' do
        expect(client.calls).to receive(:create).with(
          url: "https://app/call_online/12223334444",
          to: '+18339782511',  # online support
          from: '+19998887777',
          status_callback: 'https://app/call_status/online',
        )
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /Calling EDD Online Support/)
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+14152408408', /Calling started/)
        post '/incoming_sms', Body: 'online', From: '+12223334444'
      end

      it 'sets appropriate keys in redis' do
        post '/incoming_sms', Body: 'online', From: '+12223334444'

        expect(redis.get("current_call-12223334444")).to eq('MockCallSid')
        expect(redis.get("caller-MockCallSid")).to eq('+12223334444')
        expect(redis.get('call_count-12223334444')).to eq("1")
        expect(redis.get('active-12223334444')).to eq("online")
      end

      it 'does not allow a user to be calling from multiple queues at once' do
        redis.set('active-12223334444', "online")
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /We are already making calls for you/)
        expect_any_instance_of(ApplicationController).to_not receive(:call_edd)
        post '/incoming_sms', Body: 'online', From: '+12223334444'
      end

      it 'is possible to turn off calling' do
        redis.set('active-12223334444', "online")
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /We will stop calling for you/)
        post '/incoming_sms', Body: 'done', From: '+12223334444'
        expect(redis.get("active-12223334444")).to be_nil
      end

      it 'reports current status' do
        redis.set('active-12223334444', "online")
        redis.set('call_count-12223334444', "10")
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', "Currently calling: online\nCalls so far: 10")
        post '/incoming_sms', Body: 'status', From: '+12223334444'
      end
    end

    context 'when after hours for the main queue' do
      before do
        tz = TZInfo::Timezone.get('US/Pacific')
        now = tz.local_time(2020, 1, 1, 13, 0, 0)
        Timecop.freeze(now)
      end

      xit 'does not allow calling' do
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /That line is closed/)
        post '/incoming_sms', Body: 'main', From: '+12223334444'
      end
    end

    context 'on a weekend' do
      before do
        tz = TZInfo::Timezone.get('US/Pacific')
        now = tz.local_time(2020, 1, 4, 11, 0, 0)
        Timecop.freeze(now)
      end

      xit 'does not allow calling main' do
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /That line is closed/)
        post '/incoming_sms', Body: 'main', From: '+12223334444'
      end

      it 'allows calling online' do
        expect_any_instance_of(ApplicationController).to_not receive(:sms).with('+12223334444', /That line is closed/)
        post '/incoming_sms', Body: 'online', From: '+12223334444'
      end
    end

    context 'when after hours for online queue' do
      before do
        tz = TZInfo::Timezone.get('US/Pacific')
        now = tz.local_time(2020, 01, 01, 21, 0, 0)
        Timecop.freeze(now)
      end

      it 'does not allow calling' do
        expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /That line is closed/)
        post '/incoming_sms', Body: 'online', From: '+12223334444'
      end
    end

    it 'assigns an available number from the pool'

    it 'gracefully handles concurrent commands'

    it 'checks a list of allowed callers'

    it 'can add a number'

    it 'texts the number that was added to invite them'

  end

end
