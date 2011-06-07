# -*- coding : utf-8 -*-

require "json"
require "sinatra"
require "haml"
require "sass"
require "./lib/motosega.rb"

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

get "/?" do
	haml :indice
end

post "/result" do
	@specie_ricerca = selezionate_specie(params[:species]) # selezionate_specie difinito in ./lib/motosega.rb
	@query = params[:query]
	@risultati = sega_ricerca(@specie_ricerca, @query) # sega_ricerca definito in ./lib/motosega.rb
	
	if  @risultati == false
		haml :riprovare
	elsif @risultati == "nessun risultato"
		haml :nessun_risultato
	else
		haml :risultati
	end
end

not_found do
	haml :quattrocentoquattro
end
