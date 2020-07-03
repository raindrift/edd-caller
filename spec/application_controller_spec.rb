require 'twilio-ruby'
require_relative "spec_helper"


describe ApplicationController do
  it "responds with a welcome message" do
    get '/'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("droids")
  end
end
