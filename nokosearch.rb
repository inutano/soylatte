# -*- coding: utf-8 -*-

require "json"
require "pp"

def nokosearch(dbdono,query)
# argument: json format file path, search query

	# reject bad query
	sagashimono = query
	if sagashimono.length > 35 or sagashimono.length < 3
		return "error: length error. try another word"
	elsif sagashimono.include?(";") or sagashimono.include?(")")
		return "cazzo!"
	elsif
		# start searching
		tree = open(dbdono) { |f| JSON.load(f) }
		search_result = []
		
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
#	pp nokosearch("ksrnk_json/H_sapiens.json","HeLa")

end
