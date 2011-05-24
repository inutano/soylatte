# -*- coding : utf-8 -*-

require "json"
require "sinatra"
require "haml"
require "./nokosearch.rb"

set :haml, :format => :html5

get "/" do
	haml :index
end

post "/result" do
	
	query = params[:query]
	searchdb = "ksrnk_json/H_sapiens.json" # future: select with radio button or something
	
	@query = query
	@result = nokosearch(searchdb,query)
	open("query.log","a") { |f| f.puts(query) }
	
	haml :result
end

not_found do
	redirect "/"
end
