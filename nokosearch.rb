# -*- coding: utf-8 -*-

require "json"
require "pp"

def querychecker(query)
	fault = []
	deadballs = [";", "(", ")", "<", ">", "script", "alert", "drop", "table" ]
	deadballs.each do |bad|
		if query.include?(bad)
			fault.push(":(")
		end
	end
	if query.length > 40 or query.length < 3
		fault.push(":(")
	end

	if fault.length > 2
		return "enemy"
	elsif fault.length == 2
		return "mistake"
	else
		return "ok"
	end
end

def nokosearch(dbdono,query)
# argument: json format file path, search query

	search_result = []
	multiquery = query.split(/\s/)
	tree = open(dbdono) { |f| JSON.load(f) }
		
	multiquery.each do |sagashimono|

		# start searching
		tree.each do |content|
			desuzo = []
			
			# search in study
			study_abst = content[1][1]
			study_desc = content[1][2]
			
			if study_abst.include?(sagashimono) or study_desc.include?(sagashimono)
				desuzo.push("desuzooo")
			end
			
			# search in experiment
			if desuzo.length == 0
				content[2].each do |exp|
					exp_design = exp[1]
					exp_lib = exp[2]
					
					if exp_design.include?(sagashimono) or exp_lib.include?(sagashimono)
						desuzo.push("desuzoooooo")
					end
				end
			end
			
			# search in sample
			if desuzo.length == 0
				content[3].each do |sample|
					sample_desc = sample[1]
					if sample_desc.include?(sagashimono)
						desuzo.push("desuzooooooooo")
					end
					
					if sample[2][1]
						sample_attr = sample[2][1]
						if sample_attr.include?(sagashimono)
							desuzo.push("desuzooooooooo")
						end
					end
				end
			end
						
			# search in pubmed abstract
			if desuzo.length == 0
				pm_title = content[6]
				pm_abst = content[9]
				
				if pm_title.include?(sagashimono) or pm_abst.include?(sagashimono)
						desuzo.push("desuzoooooooooooo")
				end
			end
			
			if desuzo.length > 0			
				
				colored = '<font color="#FF8C00"><strong>' + sagashimono + '</strong></font>'
				
				content[1][1].gsub!(sagashimono,colored)
				content[1][2].gsub!(sagashimono,colored)
				
				content[2].each do |exp|
					exp[1].gsub!(sagashimono,colored)
					exp[2].gsub!(sagashimono,colored)
				end
				
				content[3].each do |sample|
					sample[1].gsub!(sagashimono,colored)
					if sample[2][1]
						sample[2][1].gsub!(sagashimono,colored)
					end
				end
				
				content[6].gsub!(sagashimono,colored)
				content[9].gsub!(sagashimono,colored)
				
				search_result.push(content)
			end
		end # end of itelator

		if search_result.length == 0
			return "no dataset found."
		else
			return search_result
		end
	end
end

if __FILE__ == $0

# for test
	pp nokosearch("ksrnk_json/H_sapiens.json","HeLa")

end
