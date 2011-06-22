# -*- coding : utf-8 -*-

require "json"
require "sinatra"
require "haml"
require "sass"
require "./lib/search_engine.rb"

set :haml, :format => :html5

before do
	open("./log/query.log","a") { |f|
		if params[:query]
			f.puts(Time.now)
			f.puts(params[:species])
			f.puts(params[:query])
		end
	}
end

get "/stylesheet.css" do
	sass :stylesheet
end

get "/failed.css" do
	sass :failed
end

get "/result.css" do
	sass :result
end

get "/*", :agent => /MSIE (4|5|6|7|8)/ do
	haml :iemustdie
end

get "/?" do
	haml :index
end

get "/about" do
	haml :tutorial
end

post "/result" do
	@organism = select_species(params[:species])
	@query = params[:query]
	@result = nokosearch(@organism, @query)
	
	if  @result == false
		haml :retry
	elsif @result == "no result"
		haml :no_result
	else
		haml :result
	end
end

not_found do
	haml :not_found
end
