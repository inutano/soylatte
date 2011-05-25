# -*- coding : utf-8 -*-

require "json"
require "sinatra"
require "haml"
require "./nokosearch.rb"

set :haml, :format => :html5

before do
	@searchdb = "./ksrnk_json/H_sapiens.json" # future: select with radio button or something
end

helpers do	
	def querychecker(query)
		watashiwoamariokorasenaihougaii = []
		badletters = [";", "(", ")", "<", ">", "script", "alert", "xml"]
		badletters.each do |bad|
			if query.include?(bad)
				watashiwoamariokorasenaihougaii.push(":(")
			end
		end
		if query.length > 40 or query.length < 3
			watashiwoamariokorasenaihougaii.push(":(")
		end
		if watashiwoamariokorasenaihougaii.length > 2
			return "enemy"
		elsif watashiwoamariokorasenaihougaii.length == 2
			return "mistake"
		else
			return "ok"
		end
		open("query.log","a") { |f| f.puts(query) }	
	end
end

get "/" do
	haml :index
end

post "/result" do
	
	@query = params[:query]
	pass unless querychecker(@query) == "enemy"
	haml :bullshit
end

post "/result" do
	
	@query = params[:query]
	pass unless querychecker(@query) == "mistake"
	haml :tryagain
end

post "/result" do
	
	@query = params[:query]	
	@result = nokosearch(@searchdb, @query)
	pass if @result == "no dataset found."
	
	haml :result
end

not_found do
	haml :not_found
end
