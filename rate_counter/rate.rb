#
# auto rate calcuration
#
class Rate 
	
	def initialize
		@total = 0
		@count = {}
		@keys  = []
	end
	
	def entry(no_or_key)
		if /^\d+$/ =~ no_or_key then
			no = no_or_key.to_i - 1
			return if no >= @keys.length
			key = @keys[no]
		else
			key = no_or_key
		end
		
		if @count.include?(key) then
			@count[key] += 1
		else
			@count[key] = 1
		end
		@total += 1
	end
	
	def report
		@keys = @count.keys
		return if @keys.nil?
		
		@keys.sort!
		0.upto(@keys.length - 1) {|no|
			rate = @count[@keys[no]].to_f / @total * 100
			printf("%3d: %-20s %5.2f%\n", no + 1, @keys[no], rate)
		}
		puts "Total: #{@total}"
	end
	
	def save(fname)
		File.open(fname, "w") {|f|
			@count.each {|key, cnt|
				f.puts "#{key}\t#{cnt}\n"
			}
		}
	end
	
	def load(fname)
		@count = {}
		@total = 0
		begin
			File.foreach(fname, chomp: true) {|line|
				fields = line.split("\t")
				key = fields[0]
				val = fields[1].to_i
				#puts "key=[#{key}] val=[#{val}]"
				@count[key] = val
				@total     += val
			}
		rescue
		end
		#puts @count
	end
	
	def interaction
		while (true)
			report
			
			print "=> "
			cmd = gets.chomp
			break if cmd == '0'
			
			entry(cmd)
		end
	end
end

if $0 == __FILE__ then
	begin
	  ratefile = ARGV.shift
		ratefile = "./rate.txt" if ratefile.nil?
		rate = Rate.new
		
		rate.load(ratefile)
		rate.interaction
		rate.save(ratefile)
	end
end