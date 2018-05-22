#
#	wc.rb	word count
#
require "kconv"

class WordCount
	def initialize
		@line = 0
		@word = 0
		@char = 0
	end
	
	attr_reader(:line, :word, :char)
	
	def count(str)
		@line += 1
		
		words = str.split(' ')
		@word += words.size
		
		words.each do |word|
			@char += word.size
		end
	end
	
	def add(wc)
		@line += wc.line
		@word += wc.word
		@char += wc.char
	end
end

begin
	wcTotal = WordCount::new
	ARGV.each do |arg|
		wc = WordCount::new
		IO::foreach(arg) do |line|
		  line.chomp!
			wc.count(line)
		end
		printf("%s:\t%d %d %d\n", arg, wc.line, wc.word, wc.char)
		wcTotal.add(wc)
	end
	printf("total:\t%d %d %d\n", wcTotal.line, wcTotal.word, wcTotal.char)
end
