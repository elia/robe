require 'pp'
module Robe
  class Source
    def initialize(source, line:, column:)
      @column = column-1
      @line = line-1
      @lines = source.split("\n")
      @before_lines = lines[0..@line]
      @current_line = lines[@line]
    end
    attr_reader :lines

    def current_module_or_class
      @before_lines.join("\n").scan(/(?:module|class) ([A-Z][\w:]+)/).join("::")
    end

    def current_method
      before = @current_line[0...@column]
      after = @current_line[@column..-1]

      (before.scan(/\w+\z/) + after.scan(/\A\w+/)).join
    end

    def instance_method?
      before = @current_line[0...@column]
      before !~ /self\.\w+\z/
    end
  end
end


if $0 == __FILE__
  source = <<-RUBY
  module Robe #1
    class Source #2
      def foo #3:12
      end #4
      def self.bar #5:17
      end
    end
  end
  RUBY

  Robe::Source.class_eval {
    def foo # 4:13
    end
    def self.bar # 8:18
    end
  }

  fail unless Robe::Source.new(source, line: 3, column: 12).current_module_or_class == 'Robe::Source'

  fail unless Robe::Source.new(source, line: 3, column: 12).current_method == 'foo'
  fail unless Robe::Source.new(source, line: 3, column: 12).instance_method? == true

  fail unless Robe::Source.new(source, line: 5, column: 17).current_method == 'bar'
  fail unless Robe::Source.new(source, line: 5, column: 17).instance_method? == false
end
