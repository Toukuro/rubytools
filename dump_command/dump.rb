#!/usr/local/bin/ruby
#
#  dump.rb
#
require 'kconv'

class Dumper
  BYTES_PER_LINE = 16
  
  def initialize(fname = '')
    @fname  = ''
    @ifile  = nil
    @addr   = 0
    @zero_suppress = false
    
    open(fname) unless fname.empty?
  end
  attr_accessor(:zero_suppress)
  
  def open(fname)
    if @fname != fname then
      close
      @fname = fname
      @ifile = File.open(@fname, "rb")
      @addr  = 0
    end
  end
  
  def close
    @ifile.close unless @ifile.nil?
    @ifile = nil
  end
  
  def dump(size = 256, addr = nil)
    while size > 0
      break if @ifile.eof?
      
      dmp = ""
      asc = ""
      sum = 0
      
      buf = @ifile.read(BYTES_PER_LINE)
      buf.each_byte {|b|
        dmp += sprintf("%02x ", b)
        sum += b
        if b < 0x20 or b == 0x7f then
          asc = asc + "."
        else
          asc = asc + b.chr
        end
        #case b
        #when 0x00, 0x07, 0x08, 0x09, 0x0a, 0x0d, 0x7f
        #  asc = asc + '.'
        #else
        #  asc = asc + b.chr
        #end
      }
      #asc = asc.kconv(Kconv::EUC, Kconv::SJIS)
      printf("%08x: %-48s[%-16s]\n", @addr, dmp, asc)  unless @zero_suppress and sum == 0
      @addr += BYTES_PER_LINE
      size  -= BYTES_PER_LINE
    end
  end
  
  def dump_all()
    until @ifile.eof?
      dump
    end
  end
end

begin
  zsup_flag = false
  
  ARGV.each {|arg|
    if arg[0].chr == '-' then
      opt = arg[1 .. -1]
      case opt
      when 'z'
        zsup_flag = true
      end
      next
    end
    
    dmp = Dumper.new(arg)
    dmp.zero_suppress = zsup_flag
    dmp.dump_all
    dmp.close
  }
end
