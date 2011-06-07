# -*- coding: utf-8 -*-
require "json"
require "#{File::expand_path(File::dirname(__FILE__))}/motore_di_ricerca.rb"

def selezionate_specie(specie)
	corrente = "#{File::expand_path(File::dirname(__FILE__))}"
	if specie == "all"
		return "#{corrente}/ksrnk_json/All_species.json"
	elsif specie == "human"
		return "#{corrente}/ksrnk_json/H_sapiens.json"
	elsif specie == "mouse"
		return "#{corrente}/ksrnk_json/M_musculus.json"
	elsif specie == "arabidopsis"
		return "#{corrente}/ksrnk_json/A_thaliana.json"
	end
end

def sega_ricerca(insieme_di_dati,query_di_ricerca)
	# Preparare definito in ./motore_di_ricerca.rb
	unless Preparare.new(query_di_ricerca).query_verifica == true
		return false
	else
		scatola = []
		proiettili = Preparare.new(query_di_ricerca).query_dividere
		obiettivi = open(insieme_di_dati) { |f| JSON.load(f) }
		pp proiettili		
		proiettili.each do |pallottola|
			obiettivi.each do |obiettivo|
				if ricerca(obiettivo, pallottola) == true	# ricerca definito in ./motore_di_ricerca.rb
					scatola.push(obiettivo)
				end
			end
		end
		
		fucile_a_canna_liscia = Preparare.new(query_di_ricerca).query_dividere_singolo
		insieme_finale = scatola.uniq
		risultati = query_concentra(insieme_finale,fucile_a_canna_liscia)
		
		unless risultati.length == 0
			return risultati
		else
			return "nessun risultato"
		end
	end
end
