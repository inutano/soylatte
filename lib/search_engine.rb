# -*- coding: utf-8 -*-
require "json"
require "#{File::expand_path(File::dirname(__FILE__))}/reflexive.rb"
require "pp"

def select_species(organism)
	currentdir = "#{File::expand_path(File::dirname(__FILE__))}"
	if organism == "all"
		return "#{currentdir}/ksrnk_json/Allspecies.json"
	elsif organism == "human"
		return "#{currentdir}/ksrnk_json/Hsapiens.json"
	elsif organism == "mouse"
		return "#{currentdir}/ksrnk_json/Mmusculus.json"
	elsif organism == "arabidopsis"
		return "#{currentdir}/ksrnk_json/Athaliana.json"
	end
end

class Prepare
	def initialize(query)
		@query = query
	end

	def query_verify
		
		if @query.length > 40 or @query.length < 3 or @query.empty?
			return nil
		else
			query_censored = @query
			illegal_symbols = [";", "(", ")", "<", ">", "?"]
			illegal_symbols.each do |sym|
				query_censored.gsub!("#{sym}","")
			end
			return query_censored
		end
	end

	def query_separater
		not_separated = [@query]
		separated = @query.split(/\s/)
		query_list = not_separated + separated
		return query_list
	end
	
	def query_separater_single
		return @query.split(/\s/)
	end
end

class SearchEngine
	def initialize(set, query)
		@set = set # one set of metadata
		@query = query
	end

	def search_acc
		acc_id = @set[0]
		if acc_id.index(/#{@query}/i)
			return true
		end
	end
	
	def search_pubmed
		count = 0
		@set[1].each do |s|
			pm_id = s[0]
			pm_title = s[1]
			pm_jrnl = s[2]
			pm_abst = s[5]
			pm_auth = s[6]
			pm_field = [pm_id, pm_title, pm_jrnl, pm_abst, pm_auth]
			pm_field.each do |pmf|
				if pmf.index(/#{@query}/i)
					count += 1
				end
			end
		end
		if count != 0
			return true
		end
	end
	
	def search_study
		if @set[2].class == Array # if metadata doesn't exist, set[2] is String.
			study_id = @set[2][0]
			study_abst = @set[2][1]
			study_desc = @set[2][2]
			if study_id.index(/#{@query}/i) or study_abst.index(/#{@query}/i) or study_desc.index(/#{@query}/i)
				return true
			end
		end
	end
	
	def search_exp
		if @set[3].class == Array
			count = 0
			@set[3].each do |exp|
				exp_id = exp[0]
				design = exp[1]
				lib = exp[2]
				platform = exp[3]
				space = exp[4]
				sample_id = exp[5]
				
				exp_field = [exp_id, design, lib, platform, space, sample_id]
				exp_field.each do |exf|
					if exf.index(/#{@query}/i)
						count += 1
					end
				end
				
				if exp[6].class == Array
					exp[6].each do |run|
						run_id = run[0]
						if run_id.index(/#{@query}/i)
							count += 1
						end
					end
				end
			end
			if count != 0
				return true
			end
		end
	end
	
	def search_sample
		if @set[4].class == Array
			count = 0 
			@set[4].each do |sample|
				sample_id = sample[0]
				sample_desc = sample[1]
				if sample_id.index(/#{@query}/i) or sample_desc.index(/#{@query}/i)
					count += 1
				end
				sample[2].each do |attr|
					attr_tag = attr[0]
					attr_val = attr[1]
					if attr_tag.index(/#{@query}/i) or attr_val.index(/#{@query}/i)
						count += 1
					end
				end	
			end
			if count != 0
				return true
			end
		end
	end
end # end of class SearchEngine


def db_search(dataset,query)
	noko = SearchEngine.new(dataset, query)
	if noko.search_acc
		return true
	elsif noko.search_pubmed
		return true
	elsif noko.search_study
		return true
	elsif noko.search_exp
		return true
	elsif noko.search_sample
		return true
	else
		return false
	end
end

def query_highlight(dataset, queryset)
	result = []
	dataset.each do |set|
		queryset.each do |query|
			tag_inserted = '<font color="#E597B2"><strong>' + query + '</strong></font>'			
			set.reflexive_map! do |s|
				if s.class == String
					s.gsub(/#{query}/i, tag_inserted)
				end
			end
		end
		result.push(set)
	end
	return result
end
	
def nokosearch(path_json_db, querydono)
	query = Prepare.new(querydono).query_verify
	
	if !query
		return false
	else
		match_box = []
		query_list = Prepare.new(query).query_separater
		target_db = open(path_json_db) { |f| JSON.load(f) }
		query_list.each do |q|
			target_db.each do |set|
				if db_search(set, q)
					match_box.push(set)
				end
			end
		end
		
		queries_for_highlight = Prepare.new(query).query_separater_single
		list_uniq = match_box.uniq
		result = query_highlight(list_uniq, queries_for_highlight)
		
		if !result.empty?
			return result
		else
			return "no result"
		end
	end
end
	
if __FILE__ == $0
# :)
# debug 
#	pp nokosearch("./ksrnk_json/TranscriptomeAnalysis_Allspecies.json", "grapevine")
end
