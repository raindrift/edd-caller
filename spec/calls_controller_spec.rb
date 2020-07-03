require_relative "spec_helper"

describe CallsController do
  describe 'calling main' do
    it "calls back the right person, and normalizes the number" do
      post '/call_main/12223334444'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("+12223334444")
    end
  end

  describe 'calling online support' do
    it "calls back the right person, and normalizes the number" do
      post '/call_online/12223334444'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("+12223334444")
    end
  end
end
