require "c:/tools/BrxLogger"
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
        # @param  type    [Integer]     スタイルのタイプ
        # @param  name    [String]      定義名
        # @param  pattern [String]      定義パターン
        def initialize(type, name, pattern = nil, value = nil)
            @style_type = type
            @name     = name
            @pattern  = pattern
            @value    = value
        end
        attr_reader :value

        # スタイルとしてオブジェクトを生成
        # @param  name    [String]      定義名
        # @param  pattern [String]      定義パターン
        def self.newStyle(name, pattern, value = nil)
            return self.new(ST_STYLE, name, pattern, value)
        end

        # 変数としてオブジェクトを生成
        # @param  name    [String]      定義名
        # @param  pattern [String]      定義パターン
        def self.newVar(name, pattern, value = nil)
            return self.new(ST_VARIABLE, name, pattern, value)
        end

        # Loggerの設定
        # @param  val   [Logger]        Loggerオブジェクト
        def self.logger=(val)
            @@log = val
        end

        # スタイルの評価
        # @param  args  [String[]]      引数
        # @return       [String]        評価結果
        def eval(args)
            # @value = args[0]
            # @@log.debug("set style var name: #{@name} value: #{@value}")
            # return nil if @style_type == ST_VARIABLE

            result = String.new(@pattern)
            @@log.debug("before result: '#{result}' args: #{args}")

            if result.include?('$*') then
                result.gsub!('$*', args.join(' '))
                args = []
            else
                max_idx = -1
                while (md = /\$(\d+)/.match(result))
                    idx = md[1].to_i - 1
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
            @@log.debug("after  result: '#{result}' args: #{args}")

            # 変数タイプは展開結果を値として保持
            if @style_type == ST_VARIABLE then
                @value = result
                return args
            end

            #return result.split(' ') + args
            return [result] + args
        end
    end
    #--------------------------------

    # クラス変数＆クラスメソッド
    @@log = nil

    # Loggerの設定
    # @param  val   [Logger]    Loggerオブジェクト
    def self.logger=(val)
        @@log = val
        Style.logger  = @@log
    end

    # コンストラクタ
    def initialize()
        @styles       = {}
        @aliases      = {}
        @include_path = nil
        
        @styles['>'] = Style.newVar('>', '    ', '    ')
        @styles['.'] = Style.newVar('.', "\n", "\n")
    end
    attr_accessor :include_path

    #
    # @param  fname   [String]
    # @return
    def parse(fname)
        IO.foreach(fname) do |line|
            fields = line.chomp.split(" ")
            @@log.info("<<<<< fields: #{fields}")

            next if fields.empty?
            result = eval(fields)

            # スタイル変数の置換
            unless result.nil?
                result.each do |str|
                    str = replace_stylevar(str)
                end
            end
            @@log.info(">>>>> result: #{result}")

            puts result.join(' ') unless result.nil?
        end
    end 

    # スタイルおよびスタイル変数の評価
    # @param  fields  [String[]]
    # @return   [String[]]
    def eval(fields)
        return [] if fields.nil? || fields.empty? 

        # fieldsの後ろから評価する
        top_word = fields.shift
        result = eval(fields)
        @@log.debug("top_word: #{top_word} result: #{result}")

        if top_word.start_with?('.') then
            sty_cmd  = top_word[1..-1]
            sty_name = result.shift
            sty_pattern = result.join(' ')

            case sty_cmd
            when '#'    # comment
                result = nil
            when 'include'
                @@log.info("include: fname='#{sty_name}'")
                include(sty_name)
                result = nil
            when 'styledef'
                @@log.info("styledef: name='#{sty_name}' pattern='#{sty_pattern}'")
                @styles[sty_name] = Style.newStyle(sty_name, sty_pattern)
                result = nil
            when 'vardef'
                @@log.info("vardef: name='#{sty_name}' pattern='#{sty_pattern}'")
                @styles[sty_name] = Style.newVar(sty_name, sty_pattern)
                result = nil
            when 'alias'
                @@log.info("alias: name='#{sty_name}' pattern='#{sty_pattern}'")
                @aliases[sty_name] = sty_pattern
                result = nil
            else
                # スタイルの展開
                result.unshift(sty_name)
                result = expand_style(sty_cmd, result)
            end  
        else
            result.unshift(top_word)
        end

        return result
    end

    #--------------------------------   プライベートメソッド
    private

    # include処理
    # @param fname  [String]    インクルードファイル名
    def include(fname)
        unless File.exist?(fname) then
            fname = File.join(@include_path, fname) unless @include_path.nil?
            unless File.exist?(fname) then
                puts "*** include file not found. [#{fname}]"
                return
            end
        end
        parse(fname)
    end

    # スタイルの展開
    # @param sty_cmd    [String]    スタイルコマンド
    # @param args       [String[]]  引数
    def expand_style(sty_cmd, args)
        # エイリアスの解決
        while @aliases.include?(sty_cmd)
            sty_cmd = @aliases[sty_cmd]
        end

        # スタイルの解決
        unless @styles.include?(sty_cmd) then
            puts "*** style not defiend. [#{sty_cmd}]"
            return nil
        end
        
        return @styles[sty_cmd].eval(args)
    end

    # スタイル変数の置換
    # @param str    [String]    置換対象の文字列
    # @return       [String]    置換済みの文字列
    def replace_stylevar(str)
        return str if str.nil? || str.empty?

        while (md = /\$([A-Za-z_]\w+|\.|\>)/.match(str))
            @@log.debug("str: #{str} varname: #{md[1]}")
            if @styles[md[1]].nil? then
                puts "*** style var not defined. [#{md[1]}]"
                break
            end
            str[md.begin(0), md[0].length] = @styles[md[1]].value || ''
        end
        return str
    end
end

#--------------------------------
begin
    # Encodingの設定
    Encoding.default_external = Encoding::UTF_8

    # ログ出力オブジェクトの生成と設定
    log = BrxLogger.new("mdc")
    log.level = Logger::Severity::INFO
    MarkdownConverter.logger = log
    log.info("========== mdc start.")

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
            when 'D'
                log.level = Logger::Severity::DEBUG
            end
            next
        end
        # オプション以外はファイル名とみなして、変換を実行
        mdc.parse(arg)
    end  
    log.info("========== mdc end.")
end
