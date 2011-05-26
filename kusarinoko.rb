# -*- coding : utf-8 -*-

require "json"
require "sinatra"
require "haml"
require "./nokosearch.rb"

set :haml, :format => :html5

before do
	species = params[:species]
	if species == "all"
		@searchdb = "./ksrnk_json/All_species.json"
	elsif species == "human"
		@searchdb = "./ksrnk_json/H_sapiens.json"
	elsif species == "mouse"
		@searchdb = "./ksrnk_json/M_musculus.json"
	else
		@searchdb = "./ksrnk_json/A_thaliana.json"
	end

	open("query.log","a") { |f|
		f.puts(params[:species])
		f.puts(params[:query])
	}
end

get "/" do
	haml :index
end

post "/result" do
	@query = params[:query].force_encoding("UTF-8")
	@result = nokosearch(@searchdb, @query)
	
	if querychecker(@query) == "enemy"
		haml :bullshit
	elsif querychecker(@query) == "mistake"
		haml :tryagain
	else
		unless @result == "no dataset found."
			haml :result
		else
			haml :not_found
		end
	end
end

not_found do
	haml :quattrocentoquattro
end
