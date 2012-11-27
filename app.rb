# -*- coding: utf-8 -*-

require "sinatra"
require "haml"
require "sass"

get "/" do
  haml :index
end

post "/search" do
  query_raw = params[:query]
  query = queryfilter(query_raw)
  result = soy_search(query)
  if result
    haml :search
  else
    haml :search_failed
  end
end
