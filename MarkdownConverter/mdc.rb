require "Logger"
#
# mdc.rb  Markdown Converter
#
class MarkdownConverter

  @@log = Logger.new("mdc-#{Time.now.strftime('%Y%m%d')}.log")

  #--------------------------------
  # Style 定義クラス
  class Style

    # スタイルのタイプ
    ST_NONE     = 0
    ST_STYLE    = 1   # スタイルとして定義。評価結果を返却する
    ST_VARIABLE = 2   # 変数として定義。評価結果は返却しない

    @@log

    # デフォルトコンストラクタ
    # @param  type    [Integer]   スタイルのタイプ
    # @param  name    [String]    定義名
    # @param  pattern [String[]]  定義パターン
    def initialize(type, name, pattern = nil)
      @style_type = type
      @name     = name
      @pattern  = pattern
      @value    = nil
      Encoding.default_external = Encoding::UTF_8
    end
    attr_reader :value
  
    # スタイルとしてオブジェクトを生成
    # @param  name    [String]    定義名
    # @param  pattern [String[]]  定義パターン
    def self.newStyle(name, pattern)
      @@log.debug("*** newStyle: name=#{name} pattern=#{pattern}")
      return self.new(ST_STYLE, name, pattern)
    end
  
    # 変数としてオブジェクトを生成
    # @param  name    [String]    定義名
    # @param  pattern [String[]]  定義パターン
    def self.newVar(name, pattern)
      @@log.debug("*** newVar: name=#{name} pattern=#{pattern}") 
      return self.new(ST_VARIABLE, name, pattern)
    end

    # Loggerの設定用
    # @param  val   [Logger]
    def self.Logger=(val)
      @@log = val
    end

    # スタイルの評価
    # @param  args  [String[]]  引数
    # @return       [String]    評価結果
    def eval(args)
      @value = args[0]
      return nil if @style_type == ST_VARIABLE

      result = @pattern.join(' ')
      if result.include?('$*') then
        result.gsub!('$*', args.join(' '))
        args = []
      else
        (1..args.length).each do |n|
          pattern = "$#{n}"
          ret.gsub!(pattern, args[n - 1])
        end
        max_idx = 0
        while (md = /\$(\d+)/.match(result))
          idx = md[1].to_i - 1
          max_idx = max_idx < idx ? idx : max_idx
          result[md.begin(0),md[0].length] = args[idx]
        end
        if args.length > max_idx + 1 then
          args = args[max_idx + 1, -1]
        else
          args = []
        end
      end
      return [result] + args
    end
  end

  # コンストラクタ
  def initialize()
    @styles       = {}
    @aliases      = {}
    @include_path = nil
    Style.Logger  = @@log
  end
  attr_accessor :include_path

  # スタイルおよびスタイル変数の評価
  # @param  fields  [String[]]
  def eval(fields)
    @@log.debug("*** eval: fields:#{fields}")
    return [] if fields.nil? || fields.empty? 

    # fieldsの後ろから評価する
    car = fields[0]
    cdr = fields[1..-1]
    result = eval(cdr)

    if car.start_with?('.') then
      sty = car[1..-1]
      # エイリアスの解決
      while @aliases.include?(sty)
        sty = @aliases[sty]
      end
      
      # スタイルの解決
      unless @styles.include?(sty) then
        puts "*** style not defiend. [#{sty}]"
        return result
      end
      result = @styles[sty].eval(result)
    else
      result.unshift(car)
    end
    return result
  end

  #
  # @param  fname   [String]
  def parse(fname)
    IO.foreach(fname) do |line|
      fields = line.chomp.split(" ")
      @@log.debug("*** parse: fields:#{fields}")

      next if fields.empty?

      if fields[0].start_with?('.') then
        cmd = fields[0][1..-1]
        def_name = fields[1]
        def_val  = fields[2..-1]

        case fields[0]
        when ".#"
          # comment
        when ".include"
          inc_name = def_name
          unless File.exist?(inc_name) then
            inc_name = File.join(@include_path, inc_name) unless @include_path.nil?
            unless File.exist?(inc_name) then
              puts "*** include file not found. [#{def_name}]"
              next
            end
          end
          parse(inc_name)
        when ".styledef"
          @styles[def_name] = Style.newStyle(def_name, def_val)
        when ".vardef"
          @styles[def_name] = Style.newVar(def_name, def_val)
        when ".alias"
          @aliases[def_name] = def_val[0]
        else
          result = eval(fields).join(' ')
          while (md = /\$(\w+)/.match(result))
            result[md.begin(0),md[0].length] = @variable[md[1]]
          end
          puts result
        end  
      else
        puts fields.join(' ')
      end
    end
  end 
end
  
begin
  mdc = MarkdownConverter.new

  until ARGV.empty? do
    arg = ARGV.shift
    if arg.start_with?('-') then
      opt = arg[1..-1]
      case opt
      when 'I'
        mdc.include_path = ARGV.shift
      end
      next
    end
    mdc.parse(arg)
  end  
end