# :)

require File.join(PROJ_ROOT, 'lib', 'soylattedb/reference')
require File.join(PROJ_ROOT, 'lib', 'soylattedb/scheme')
require File.join(PROJ_ROOT, 'lib', 'soylattedb/sra')
require File.join(PROJ_ROOT, 'lib', 'soylattedb/publication')

Groonga::Context.default_options = { encoding: :utf8 }

class SoylatteDB
end
