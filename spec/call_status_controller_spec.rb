require 'twilio-ruby'
require 'tzinfo'
require_relative "spec_helper"

describe CallStatusController do

  # spy on redis so we can get access to the same instance
  let(:redis) { MockRedis.new }
  before do
    allow_any_instance_of(ApplicationController).to receive(:connect_redis).and_return(redis)
  end

  after do
    Timecop.return
  end

  describe 'sms_incoming' do
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

      redis.set("caller-MockCallSid", '+12223334444')
    end

    context "with correct values in redis" do
      before do
        tz = TZInfo::Timezone.get('US/Pacific')
        now = tz.local_time(2020, 1, 1, 12, 0, 0)
        Timecop.freeze(now)
        redis.set("call_count-12223334444", "1")
      end

      context "with a long call" do
        it "stops calling and texts to say we are done (main)" do
          expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /Looks like maybe you got through?/)
          redis.set('active-12223334444', "main")

          post '/call_status/main', CallDuration: 180, CallSid: 'MockCallSid'
          expect(redis.lindex("successes-main", -1)).to eq('20200101120000:1')
        end

        it "stops calling and texts to say we are done (online)" do
          expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /Looks like maybe you got through?/)
          redis.set('active-12223334444', "online")

          post '/call_status/online', CallDuration: 120, CallSid: 'MockCallSid'
          expect(redis.lindex("successes-online", -1)).to eq('20200101120000:1')
        end
      end

      context "with a short call" do
        it "tries again (main)" do
          expect_any_instance_of(ApplicationController).to receive(:call_edd).with(:main, '+12223334444', false)
          redis.set('active-12223334444', "main")

          post '/call_status/main', CallDuration: 160, CallSid: 'MockCallSid'
        end

        it "tries again (online)" do
          expect_any_instance_of(ApplicationController).to receive(:call_edd).with(:online, '+12223334444', false)
          redis.set('active-12223334444', "online")

          post '/call_status/online', CallDuration: 30, CallSid: 'MockCallSid'
        end
      end

      context "when it is after hours" do
        before do
          tz = TZInfo::Timezone.get('US/Pacific')
          now = tz.local_time(2020, 1, 1, 7, 0, 0)
          Timecop.freeze(now)
          redis.set("call_count-12223334444", "1")
        end

        it "stops calling and texts to say meh next time (main)" do
          expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /The number we were calling is now closed/)
          redis.set('active-12223334444', "main")

          post '/call_status/main', CallDuration: 50, CallSid: 'MockCallSid'
          expect(redis.lindex("failures-main", -1)).to eq('20200101070000:1')
        end

        it "stops calling and texts to say meh next time (online)" do
          expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /The number we were calling is now closed/)
          redis.set('active-12223334444', "online")

          post '/call_status/online', CallDuration: 50, CallSid: 'MockCallSid'
          expect(redis.lindex("failures-online", -1)).to eq('20200101070000:1')
        end
      end

      context "when the user has said they are done" do
        it "does not call" do
          expect_any_instance_of(ApplicationController).to receive(:sms).with('+12223334444', /We made 10 calls for you this time./)
          expect_any_instance_of(ApplicationController).to_not receive(:call_edd)
          redis.set('call_count-12223334444', "10")
          # active is not set
          post '/call_status/online', CallDuration: 30, CallSid: 'MockCallSid'
        end
      end
    end

    context "with missing call data" do
      it "fails in some reasonable way"
    end
  end

end
