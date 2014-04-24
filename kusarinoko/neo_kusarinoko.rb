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
			time = Time.now
			species = params[:species]
			query = params[:query]
			f.puts("#{time}\t#{species}\t#{query}")
		end
	}
end

get "/stylesheet.css" do
	sass :stylesheet
end

get "/tutorial.css" do
	sass :tutorial
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

get "/show/:id" do |id|
	if id && id =~ /^(S|E|D)R(A|P|S|R|X)\d{6}$/
		@organism = select_species("all")
		@query = id
		@result = nokosearch(@organism, @query)
		
		if @result == "no result"
			haml :no_result
		else
			haml :result
		end
	else
		haml :retry
	end
end

not_found do
	haml :not_found
end
