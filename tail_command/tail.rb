# coding: shift_jis
#
#	tail.rb
#
require "kconv"

def fgets(f, istrim)
  s = f.gets
  return s if s.nil?
  return istrim ? s.sub(/\s*$/, '') : s
end

begin
	NOTSET = 0
	FBYTES = 1
	FLINES = 2
	RBYTES = 3
	RLINES = 4

	style, offset = RLINES, 10
	isfifo = false
	istrim = false
	files  = []
	encode = "SHIFT_JIS"

	while arg = ARGV.shift
		if arg[0].chr == "-" then
			optsw = arg[1..-1]
			
			case optsw
			when "n"
				optval = ARGV.shift
				case optval[0].chr
				when "+"
					style, offset = FLINES, optval.to_i
				when "-"
					style, offset = RLINES, -optval.to_i
				else
					style, offset = RLINES, optval.to_i
				end

			when "c"
				optval = ARGV.shift
				case optval[0].chr
				when "+"
					style, offset = FBYTES, optval.to_i
				when "-"
					style, offset = RBYTES, -optval.to_i
				else
					style, offset = RBYTES, optval.to_i
				end

			when "b"
				optval = ARGV.shift
				case optval[0].chr
				when "+"
					style, offset = FBYTES, optval.to_i * 512
				when "-"
					style, offset = RBYTES, -optval.to_i * 512
				else
					style, offset = RBYTES, optval.to_i * 512
				end

			when "f"
				isfifo = true
			
			when "t"
			  istrim = true
			
			when "h"
				puts "usage: ruby tail.rb [-f] [-n number] [-c number] [-b number] <file> ..."
				puts "	-f: FIFO ���[�h�BEOF�ɒB���Ă��t�@�C�����N���[�Y���܂���B"
				puts "	-n: �t�@�C���̖��� number �s��\\���B"
				puts "	-c: �t�@�C���̖��� number �o�C�g��\\���B"
				puts "	-b: �t�@�C���̖��� number �u���b�N��\\���B�i1�u���b�N=512�o�C�g�j"
				puts "	-t: �s���̋󔒂��폜"
				puts "	-h: ���̃��b�Z�[�W��\\���B"
			else
				puts "tail.rb: �w�肳�ꂽ�I�v�V�����͖����ł��B[#{optsw}]"
				puts "'-h'�I�v�V�������w�肵�āA�w���v���Q�Ƃ��Ă��������B"
			end
		else
			files.push(arg)
		end
	end

	if files.size > 1 then
		isfifo = false
	end

#	styles = ["NOTSET","FBYTES","FLINES","RBYTES","RLINES"]
#	puts "style=#{styles[style]}, offset=#{offset}"
	
	files.each do |arg|
		puts "\n==> #{arg} <==" if files.size > 1
		File::open(arg, "r") do |f|
			case style
			when FBYTES
				f.seek(offset)
				until f.eof? do
					puts fgets(f, istrim).tosjis
				end
			when FLINES
				offset.times { f.gets }
				until f.eof? do
					puts fgets(f, istrim).tosjis
				end
			when RBYTES
				f.seek(-offset, IO::SEEK_END)
				until f.eof? do
					puts fgets(f, istrim).tosjis
				end
			when RLINES
				buffer = []
				until f.eof? do
					buffer.push(fgets(f, istrim))
					buffer.shift if buffer.size > offset
				end
				buffer.each {|s| puts s.tosjis}
			end
			
			if isfifo then
				while true
					s = fgets(f, istrim)
					puts s.tosjis	unless s.nil?
					sleep 1	if s.nil?
				end
			end
		end
	end
rescue Errno::ENOENT
	puts "tail.rb: �t�@�C�������݂��܂���B[#{arg}]"
rescue Interrupt
	exit!(0)
end

