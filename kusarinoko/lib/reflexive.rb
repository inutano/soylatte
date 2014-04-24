# -*- coding: utf-8 -*-

class Object
	class Array
		def reflexive_each(&p)
			self.each do |arr|
				if arr.class == Array
					arr.reflexive_each(&p)
				else
					p.call(arr)
				end
			end
		end
	
		def reflexive_map(&p)
			self.map do |arr|
				if arr.class == Array
					arr.reflexive_map(&p)
				else
					p.call(arr)
				end
			end
		end
	
		def reflexive_map!(&p)
			self.map! do |arr|
				if arr.class == Array
					arr.reflexive_map!(&p)
				else
					arr = p.call(arr)
				end
			end
		end
	end
end

if __FILE__ == $0
# :)
end
