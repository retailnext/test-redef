Gem::Specification.new do |s|
  s.name = 'test-redef'
  s.version = '1.0'
  s.license = 'MIT'

  s.authors = ['Nearbuy Systems']
  s.summary = 'Scoped and logged monkey patching for unit tests'
  s.description = 'Replace methods with test code, get feedback on how they are called and put it all back together when your test is done.'
  s.email = 'hackers@nearbuysystems.com'
  s.homepage = 'http://github.com/nearbuy/test-redef'

  s.files = ['README.md', 'Rakefile', 'lib/test/redef.rb', 'test/redef.rb']

  s.required_ruby_version = '>= 1.9.2'
end
