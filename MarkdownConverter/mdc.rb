require "c:/tools/BrxLogger"
#
# mdc.rb  Markdown Converter
#
class MarkdownConverter

    #--------------------------------
    # Style 定義クラス
    class Style

        @@log = nil

        # Loggerの設定
        # @param    val         [Logger]        Loggerオブジェクト
        def self.logger=(val)
            @@log = val
        end

        # デフォルトコンストラクタ
        # @param    name        [String]      定義名
        # @param    pattern     [String]      定義パターン
        # @param    
        def initialize(name, pattern = nil, value = nil)
            @name       = name
            @pattern    = unescape(pattern)
            @value      = value
        end
        attr_accessor :value

        # スタイルを評価し結果を返却する
        # @param    args    [String[]]      引数
        # @return           [String]        評価結果
        def eval_style(args)
            @@log.debug("name: #{@name}")
            @value, args = eval(args)
            result = @value.split(' ') + args
            @@log.debug("result: #{result}")
            return result
        end

        # スタイルを評価し結果を保持する
        # @param    args    [String[]]      引数
        # @return           [String]        未使用の引数
        def eval_var(args)
            @@log.debug("name: #{@name}")
            @value, args = eval(args)
            @@log.debug("result: #{args}")
            return args
        end

        #--------------------------------   プライベートメソッド
        private

        def unescape(str)
            @@log.debug("str: '#{str}'")
            unless str.nil? || str.empty? then
                str = str.gsub(/\\(.)/) {$1}
            end
            @@log.debug("str: '#{str}'")
            return str
        end

        # スタイルの評価
        # @param    args    [String[]]          引数
        # @return           [String, String]    評価結果, 未使用引数
        def eval(args)
            result = String.new(@pattern || '')
            #@@log.debug("before result: '#{result}' args: #{args}")

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
                    #@@log.debug("args: #{args} max_idx: #{max_idx}")
                    args = args[(max_idx + 1) .. -1] || []
                else
                    args = []
                end
            end
            #@@log.debug("after  result: '#{result}' args: #{args}")

            return result, args
            #return result.split(' ') + args
            #return [result] + args
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
        
        @styles['>'] = Style.new('>', '    ', '    ')
        @styles['.'] = Style.new('.', "\n", "\n")
        @styles['date'] = Style.new('date', 'date', Time.now.strftime('%Y-%m-%d'))
        @styles['time'] = Style.new('time', 'time', Time.now.strftime('%H:%M:%S'))
    end
    attr_accessor :include_path

    #
    # @param  fname   [String]
    # @return
    def parse(fname)
        IO.foreach(fname) do |line|
            fields = line.chomp.split(" ")
            @@log.info("<<<<< fields: #{fields}")

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
        return nil if fields.nil?
        return []  if fields.empty? 

        # fieldsの後ろから評価する
        field0 = fields.shift
        result = eval(fields)
        @@log.debug("field0: '#{field0}' result: #{result}")

        if field0.start_with?('.') then
            sty_name  = field0[1..-1]
            def_name = result.shift
            def_pattern = result.join(' ')

            case sty_name
            when '#'    # comment
                result = nil
            when 'include'
                @@log.info("include: fname: '#{def_name}'")
                include(def_name)
                result = nil
            when 'styledef'
                @@log.info("styledef: name: '#{def_name}' pattern: '#{def_pattern}'")
                @styles[def_name] = Style.new(def_name, def_pattern)
                result = nil
            when 'setvar'
                @@log.info("setvar: name: '#{def_name}' value: '#{def_pattern}'")
                unless @styles.include?(def_name) then
                    @styles[def_name] = Style.new(def_name, nil, def_pattern)
                else
                    @styles[def_name].value = def_pattern
                end
                result = nil
            when 'alias'
                @@log.info("alias: name: '#{def_name}' pattern: '#{def_pattern}'")
                @aliases[def_name] = def_pattern
                result = nil
            else
                # スタイルの展開
                result.unshift(def_name) unless def_name.nil?
                result = expand_style(sty_name, result)
            end  
        else
            result = (result || []).unshift(field0)
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
    # @param sty_name    [String]    スタイルコマンド
    # @param args       [String[]]  引数
    def expand_style(sty_name, args)
        @@log.debug("sty_name: '#{sty_name}' args: #{args}")

        # エイリアスの解決
        while @aliases.include?(sty_name)
            sty_name = @aliases[sty_name]
        end

        # スタイルの解決
        unless @styles.include?(sty_name) then
            puts "*** style not defiend. [#{sty_name}]"
            return nil
        end

        @@log.debug("sty_name: '#{sty_name}' args: #{args}")
        return eval(@styles[sty_name].eval_style(args))
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
