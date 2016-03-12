
# Add a command that takes the doc as input
#
#   #!/usr/bin/env bash
#
#   cd "$TM_PROJECT_DIRECTORY"
#   $TM_RUBY -S ./bin/rails runner ~/Code/robe/textmate/rails-runner.rb



robe_path = File.expand_path('~/Code/robe/lib')
$:.unshift robe_path unless $:.include?(robe_path)
require 'robe'
source = Robe::Source.new($<.read, column: ENV['TM_COLUMN_NUMBER'].to_i, line: ENV['TM_LINE_NUMBER'].to_i)

sash = Robe::Sash.new
case ARGV.first
when 'doc' then sash.doc_for(source.current_module_or_class, source.instance_method?, source.current_method)
when '…'
end
