# -*- coding: utf-8 -*-

require "sinatra"
require "haml"
require "sass"
require "yaml"

Configuration = YAML.load_file("./lib/config.yaml")
Logfile = Configuration["logfile"]

def logging(query)
  log = #{query} + "\t" + Time.now.to_s
  open(Logfile,"a"){|f| f.puts}
end

set :haml, :format => :html5

before do
   logging(query) if params[:query]
end

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

not_found do
  haml :not_found
end
