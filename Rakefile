require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
  t.warning = false
end

task default: :test

desc "Run tests with coverage information"
task :test_verbose do
  ENV['TESTOPTS'] = '-v'
  Rake::Task[:test].invoke
end

desc "Run a specific test file"
task :test_file, [:filename] do |t, args|
  if args[:filename]
    ruby "-Ilib:test #{args[:filename]}"
  else
    puts "Usage: rake test_file[test/test_sample.rb]"
  end
end
