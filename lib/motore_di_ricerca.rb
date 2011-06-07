# -*- coding: utf-8 -*-
require "json"

class Preparare
	def initialize(query)
		@query = query
	end

	def query_verifica
		fallo = []
		errori = [";", "(", ")", "<", ">", "script", "alert", "drop", "table" ]
		errori.each do |errore|
			if @query.include?(errore)
				fallo.push(":(")
			end
		end
		
		if @query.length > 40 or @query.length < 3 or @query.empty?
			false
		elsif fallo.length >= 2
			false
		else
			true
		end
	end

	def query_dividere
		tutto = [@query]
		separato = @query.split(/\s/)
		elenco_di_query = tutto + separato
		return elenco_di_query
	end
	
	def query_dividere_singolo
		return @query.split(/\s/)
	end
end

class MotorediRicerca
	def initialize(db,query)
		@db = db
		@query = query.downcase
	end
	
	def ricerca_acc
		acc_id = @db[0][0].downcase
		if acc_id.include?(@query)
			return true
		end
	end
	
	def ricerca_study
		study_id = @db[1][0].downcase
		study_abst = @db[1][1].downcase
		study_desc = @db[1][2].downcase
		if study_id.include?(@query) or study_abst.include?(@query) or study_desc.include?(@query)
			return true
		end
	end
	
	def ricerca_exp
		exp_result = []
		@db[2].each do |exp|
			exp_id = exp[0].downcase
			exp_design = exp[1].downcase
			exp_lib = exp[2].downcase
			if exp_id.include?(@query) or exp_design.include?(@query) or exp_lib.include?(@query)
				exp_result.push("yey!")
			end
		end
		unless exp_result.length == 0
			return true
		end
	end
	
	def ricerca_sample
		sample_result = []
		@db[3].each do |sample|
			sample_id = sample[0].downcase
			sample_desc = sample[1].downcase
			if sample_id.include?(@query) or sample_desc.include?(@query)
				sample_result.push("yeey!")
			end
			if sample[2][1]
				sample_attr = sample[2][1].downcase
				if sample_attr.include?(@query)
					sample_result.push("yeey!!")
				end
			end
		end
		unless sample_result.length == 0
			return true
		end
	end
	
	def ricerca_run
		run_result = []
		@db[4].each do |run|
			run_id = run[0].downcase
			if run_id.include?(@query)
				run_result.push("yeeey!")
			end
		end
		unless run_result.length == 0
			return true
		end
	end
	
	def ricerca_pubmed
		pm_id = @db[5].downcase
		pm_title = @db[6].downcase
		pm_jrnl = @db[7].downcase
		pm_abst = @db[9].downcase
		pm_auth = @db[10].downcase
		if pm_id.include?(@query) or pm_title.include?(@query) or pm_jrnl.include?(@query) or pm_abst.include?(@query) or pm_auth.include?(@query)
			return true
		end
	end
end # class Nokosearch end

def ricerca(insieme_di_dati,query_di_ricerca)
	noko = MotorediRicerca.new(insieme_di_dati, query_di_ricerca)
	if noko.ricerca_acc == true
		return true
	elsif noko.ricerca_study == true
		return true
	elsif noko.ricerca_exp == true
		return true
	elsif noko.ricerca_sample == true
		return true
	elsif noko.ricerca_run == true
		return true
	elsif noko.ricerca_pubmed == true
		return true
	else
		return false
	end
end

def query_concentra(insieme_di_dati, insieme_di_query)
	risultati = []
	insieme_di_dati.each do |dati|
		insieme_di_query.each do |query|
			concentrato = '<font color="#FF69B4"><strong>' + query + '</strong></font>'
			#acc
			dati[0][0].gsub!(query,concentrato)
			#study
			dati[1][0].gsub!(query,concentrato)
			dati[1][1].gsub!(query,concentrato)
			dati[1][2].gsub!(query,concentrato)
			#experiment
			dati[2].each do |exp|
				exp[0].gsub!(query,concentrato)
				exp[1].gsub!(query,concentrato)
				exp[2].gsub!(query,concentrato)
			end
			#sample
			dati[3].each do |sample|
				sample[0].gsub!(query,concentrato)
				sample[1].gsub!(query,concentrato)
				if sample[2][1]
					sample[2][1].gsub!(query,concentrato)
				end
			end
			#run
			dati[4].each do |run|
				run[0].gsub!(query,concentrato)
				run[1].gsub!(query,concentrato)
			end
			#pubmed
			dati[5].gsub!(query,concentrato)
			dati[6].gsub!(query,concentrato)
			dati[7].gsub!(query,concentrato)
			dati[9].gsub!(query,concentrato)
			dati[10].gsub!(query,concentrato)
		end
		
		risultati.push(dati)
	end
	
	return risultati
end
	
if __FILE__ == $0
# :)
end
