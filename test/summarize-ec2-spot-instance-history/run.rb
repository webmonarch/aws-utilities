# Simple test runner

require_relative '../utils'
require 'pathname'

Dir.chdir(File.dirname(__FILE__))

script = "../../scripts/summarize-ec2-spot-instance-history.rb"

parameters_prefix = '# Parameters: '
expected_prefix = '# Expected: '

Dir.glob("**/*.txt") do |test_input| # note one extra "*"
  headings = File.read(test_input).split("\n").select { |l| l.match('^#') }

  parameters = headings
    .select { |l| l.match("^#{parameters_prefix}")}
    .map { |l| l[parameters_prefix.length, l.length]}
    .join(" ")
    .strip

  expected = headings
    .select { |l| l.match("^#{expected_prefix}") }
    .map { |l| l[expected_prefix.length,l.length]}
    .join("\n")

  command = sep("#{script} #{parameters} < #{test_input}")

   print "'#{test_input}' running..."

  results = `#{command}`

  if ! $?.success?
    puts "ERROR! Command failed.  Check output."

    puts command

    exit 1
  end

  if (results.strip != expected)
    puts "Unexpected results!"
    puts "Expected:"
    puts expected
    puts "Actual:"
    puts results

    puts
    puts command

    puts "ERROR!  Check output."
    exit(1)
  else
    puts "Passed!"
  end
end

puts "All good!"