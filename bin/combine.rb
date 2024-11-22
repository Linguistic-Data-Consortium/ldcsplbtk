#!/usr/bin/env ruby

fns = []
out = nil
header = nil
ARGV.sort.each do |fn|
  case fn
  when /^o:/
    out = fn[2..-1]
  when /^h:/
    header = fn.split(':')[1..-1]
  else
    fns << fn
  end
end

def check_header(header)
  case header
  when %w[ file beg end text speaker ]
    :ok
  else
    :bad
  end
end

if check_header(header) != :ok
  raise 'error'
end

def get(fn, header)
  lines = File.readlines(fn)
  lines.each do |x|
    a = x.split "\t"
    if a.length != header.length
      raise "bad line"
    end
  end
  lines
end

lines = fns.map { |x| get x, header }.flatten
#puts header
#puts lines
open(out, 'w') do |fn|
  fn.puts header.join "\t"
  fn.puts lines
end

