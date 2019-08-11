require "Logger"

# 呼び出し元を出力できるLogger
class BrxLogger < Logger
    
    # コンストラクタ
    # @param basename   [String]
    def initialize(basename)
        super("#{basename}-#{Time.now.strftime('%Y%m%d')}.log")
        self.datetime_format = '%Y-%m-%d %H:%M:%S.%03d'
    end

    # デバッグレベルの出力
    # @param progname   [String]    プログラム名またはログ出力メッセージ
    def debug(progname = nil, &block)
        if block.nil? then
            super("#{get_caller(2)} : #{progname}")
        else
            super(progname, block)
        end
    end

    # ERRORレベルの出力
    # @param progname   [String]    プログラム名またはログ出力メッセージ
    def error(progname = nil, &block)
        if block.nil? then
            super("#{get_caller(2)} : #{progname}")
        else
            super(progname, block)
        end
    end

    # Fatalレベルの出力
    # @param progname   [String]    プログラム名またはログ出力メッセージ
    def fatal(progname = nil, &block)
        if block.nil? then
            super("#{get_caller(2)} : #{progname}")
        else
            super(progname, block)
        end
    end

    # INFOレベルの出力
    # @param progname   [String]    プログラム名またはログ出力メッセージ
    def info(progname = nil, &block)
        if block.nil? then
            super("#{get_caller(2)} : #{progname}")
        else
            super(progname, block)
        end
    end

    # UNKNOWNレベルの出力
    # @param progname   [String]    プログラム名またはログ出力メッセージ
    def unknown(progname = nil, &block)
        if block.nil? then
            super("#{get_caller(2)} : #{progname}")
        else
            super(progname, block)
        end
    end
    
    # WARNレベルの出力
    # @param progname   [String]    プログラム名またはログ出力メッセージ
    def warn(progname = nil, &block)
        if block.nil? then
            super("#{get_caller(2)} : #{progname}")
        else
            super(progname, block)
        end
    end

    # --------------------------------------
    private
    #
    # @param progname   [String]    プログラム名またはログ出力メッセージ
    def get_caller(level=1)
        cl = caller_locations(level, 1)
        return "#{File.basename(cl[0].path)}:#{cl[0].lineno} (#{cl[0].label})"
    end
end