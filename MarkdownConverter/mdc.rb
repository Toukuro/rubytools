require "Logger"
#
# mdc.rb  Markdown Converter
#
class MarkdownConverter

  #--------------------------------
  # Style 定義クラス
  class Style

    # スタイルのタイプ
    ST_NONE     = 0
    ST_STYLE    = 1   # スタイルとして定義。評価結果を返却する
    ST_VARIABLE = 2   # 変数として定義。評価結果は返却しない

    @@log = nil

    # デフォルトコンストラクタ
    # @param  type    [Integer]   スタイルのタイプ
    # @param  name    [String]    定義名
    # @param  pattern [String]  定義パターン
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
    # @param  pattern [String]  定義パターン
    def self.newStyle(name, pattern)
      @@log.debug("*** newStyle: name=#{name} pattern=#{pattern}")
      return self.new(ST_STYLE, name, pattern)
    end
  
    # 変数としてオブジェクトを生成
    # @param  name    [String]    定義名
    # @param  pattern [String]  定義パターン
    def self.newVar(name, pattern)
      @@log.debug("*** newVar: name=#{name} pattern=#{pattern}") 
      return self.new(ST_VARIABLE, name, pattern)
    end

    # Loggerの設定用
    # @param  val   [Logger]
    def self.logger=(val)
      @@log = val
    end

    # スタイルの評価
    # @param  args  [String[]]  引数
    # @return       [String]    評価結果
    def eval(args)
      @value = args[0]
      return [] if @style_type == ST_VARIABLE

      result = @pattern
      if result.include?('$*') then
        result.gsub!('$*', args.join(' '))
        args = []
      else
        max_idx = 0
        while (md = /\$(\d+)/.match(result))
          idx = md[1].to_i - 1
          @@log.debug("result:#{result} args[#{idx}]:#{args[idx]}")
          if args[idx].nil? then
            args = []
            break
          end
          max_idx = max_idx < idx ? idx : max_idx
          result[md.begin(0),md[0].length] = args[idx]
        end
        if args.length > max_idx + 1 then
          args = args[max_idx + 1, -1] || []
        else
          args = []
        end
      end
      return [result] + args
    end
  end
  #--------------------------------

  # クラス変数＆クラスメソッド
  @@log = nil

  #
  # @param  val   [Logger]
  def self.logger=(val)
    @@log = val
    Style.logger  = @@log
  end

  # コンストラクタ
  def initialize()
    @styles       = {}
    @aliases      = {}
    @include_path = nil
  end
  attr_accessor :include_path

  #
  # @param  fname   [String]
  # @return
  def parse(fname)
    IO.foreach(fname) do |line|
      fields = line.chomp.split(" ")
      @@log.debug("*** parse: fields:#{fields}")
      next if fields.empty?

      puts eval(fields).join(' ')
    end
  end 

  # スタイルおよびスタイル変数の評価
  # @param  fields  [String[]]
  # @return   [String[]]
  def eval(fields)
    @@log.debug("*** eval: fields:#{fields}")
    return [] if fields.nil? || fields.empty? 

    # fieldsの後ろから評価する
    car = fields[0]
    cdr = fields[1..-1]
    result = eval(cdr)

    if car.start_with?('.') then
      sty = car[1..-1]
      sty_name = result[0]
      sty_pattern = (result[1..-1] || []).join(' ')

      case sty
      when '#'
        # comment
        result = []
      when 'include'
        inc_name = sty_name
        unless File.exist?(inc_name) then
          inc_name = File.join(@include_path, inc_name) unless @include_path.nil?
          unless File.exist?(inc_name) then
            puts "*** include file not found. [#{inc_name}]"
            return []
          end
        end
        parse(inc_name)
        result = (result[1..-1] || [])
      when 'styledef'
        @styles[sty_name] = Style.newStyle(sty_name, sty_pattern)
        result = []
      when 'vardef'
        @styles[sty_name] = Style.newVar(sty_name, sty_pattern)
        result = []
      when 'alias'
        @aliases[sty_name] = sty_pattern
        result = []
      else
        # エイリアスの解決
        while @aliases.include?(sty)
          sty = @aliases[sty]
        end
        # スタイルの解決
        unless @styles.include?(sty) then
          puts "*** style not defiend. [#{sty}]"
          return []
        end
        result = @styles[sty].eval(result)

        # スタイル変数の置換
        result.each do |field|
          while (md = /\$(\w+)/.match(field))
            @@log.debug("field:#{field} varname:#{md[1]}")
            if @styles[md[1]].nil? then
              break
            end
            field[md.begin(0), md[0].length] = @styles[md[1]].value || ''
          end
        end
      end  
    else
      result.unshift(car)
    end
    return result
  end

  #--------------------------------
  private
  #
  def left_at(arry, n)
    return arry[n, -1] || []
  end
  #
  def include(fname)
  end
end
  
  #--------------------------------
  begin
  # ログ出力オブジェクトの生成と設定
  log = Logger.new("mdc-#{Time.now.strftime('%Y%m%d')}.log")
  MarkdownConverter.logger = log

  # Markdown変換オブジェクトの生成
  mdc = MarkdownConverter.new

  # 引数の処理
  until ARGV.empty? do
    arg = ARGV.shift

    # '-'で始まっていたらコマンドラインオプション
    if arg.start_with?('-') then
      opt = arg[1..-1]
      case opt
      when 'I'
        mdc.include_path = ARGV.shift
      end
      next
    end
    # オプション以外はファイル名とみなして、変換を実行
    mdc.parse(arg)
  end  
end