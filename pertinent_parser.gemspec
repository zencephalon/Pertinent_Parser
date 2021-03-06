Gem::Specification.new do |s|
  s.name = 'pertinent_parser'
  s.version = '0.0.0'
  s.date = '2014-04-28'
  s.summary = 'PertinentParser helps you compose HTML tags across existing tag boundaries.'
  s.description = 'PertinentParser helps you compose HTML tags across existing tag boundaries.'
  s.authors = ["Matthew Bunday"]
  s.email = "mkbunday@gmail.com"
  s.files = ["lib/pertinent_parser.rb", "lib/pertinent_parser/transform.rb", 
             "lib/pertinent_parser/rule.rb", "lib/pertinent_parser/text.rb"]
  s.homepage = 'https://github.com/zencephalon/Pertinent_Parser'
  s.license = 'MIT'
  s.add_runtime_dependency "hpricot", ["= 0.8.6"]
end
