class CallsController < ApplicationController
  post "/call_main/:number" do
    number = normalize_number(params['number'])
    erb :call_main, layout: nil, locals: {number: number}
  end

  post "/call_online/:number" do
    number = normalize_number(params['number'])
    erb :call_online, layout: nil, locals: {number: number}
  end
end
