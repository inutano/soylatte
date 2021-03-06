# :)

require File.join(PROJ_ROOT, 'lib', 'soylattedb')
require 'pry-byebug'

namespace :soylatte do
  db_dir = File.join(PROJ_ROOT, 'db')
  db = File.join(db_dir, 'soylatte.db')
  
  task :validate_db => db do |t|
    base = SoylatteDB::Base
    binding.pry
  end
end
