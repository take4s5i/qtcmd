#!/usr/bin/env ruby

require 'net/https'
require 'json'

VERSION = '0.1.0'

module QiitaAPI
    class Request
        HOST = 'qiita.com'
        PORT = 443
        PREFIX = '/api/v2'

        def initialize(token,user)
            @token = token
            @user = user
        end

        def with_http
            https = Net::HTTP.new(HOST,PORT)
            https.use_ssl = true
            https.verify_mode = OpenSSL::SSL::VERIFY_NONE
            https.start do |http|
                yield http
            end
        end

        def create_headers(orig_headers = {})
            headers = orig_headers.clone
            headers["Authorization"] = "Bearer #{@token}"
            headers["Content-Type"] = "application/json"
            headers
        end

        # 投稿の一覧を取得する
        def get_items()
            # TODO : ページネーションに対応する
            with_http do |http|
                res = http.get("#{PREFIX}/users/#{@user}/items")
                res.value
                JSON.parse(res.body)
            end
        end

        def post_item(title,tags,body,is_private = false,gist = false,tweet = false)
            with_http do |http|
                body = {body: body,
                        coediting: false,
                        gist: gist,
                        private: is_private,
                        tags: tags,
                        title: title,
                        tweet: tweet }
                headers = create_headers
                res = http.post("#{PREFIX}/items",JSON.dump(body),headers)
                res.value
                JSON.parse(res.body)
            end
        end

        def patch_item(id,title,tags,body,is_private = false,gist = false,tweet = false)
            with_http do |http|
                body = {body: body,
                        coediting: false,
                        gist: gist,
                        private: is_private,
                        tags: tags,
                        title: title,
                        tweet: tweet }
                headers = create_headers
                res = http.patch("#{PREFIX}/items/#{id}",JSON.dump(body),headers)
                res.value
                JSON.parse(res.body)
            end
        end
    end
end

module QtCmd
    SPACER = ' '.freeze
    INDENT = 2

    class CliOption
        def desc()
            ""
        end

        def display_name()
            ""
        end

        def to_s()
            "#{display_name} #{desc}"
        end
    end

    class ComplexOption < CliOption
        def initialize(opts,default = {})
            @opts = opts
            @default = default
        end

        def parse(args)
            hash = @default.clone

            accept = true
            while true
                return :invalid if !accept
                break if args.size == 0

                accept = false
                @opts.each do |opt|
                    x = opt.parse args 
                    case x
                    when :not_match then
                        next

                    when :invalid then
                        return :invalid
                    else
                        hash.merge! x
                        accept = true
                        break
                    end
                end
            end

            hash
        end

        def to_s()
            maxlen = @opts.map{|o| o.display_name.chars.count}.max
            lines  = @opts.map do |opt|
                name = opt.display_name + SPACER * (maxlen - opt.display_name.chars.count )
                indent = SPACER * INDENT
                desc = opt.desc.each_line.map{|s| SPACER * (maxlen + INDENT) + s}.join("\n")
                desc.slice!(maxlen + INDENT - 1)
                name + indent + desc

                # TODO : インデントがなんかおかしい
            end
            lines.join("\n")
        end
    end

    class SwitchOption < CliOption
        def initialize(name,long_name,desc)
            @name = name
            @long_name = long_name
            @desc = desc
        end

        attr_reader :name,:long_name,:desc

        def display_name()
            "-#{@name}, --#{@long_name}"
        end

        def parse(args)
            raise :not_match if args.size == 0
            return :not_match if args[0] != "-#{@name}" && args[0] != "--#{@long_name}"
            args.shift
            {"#{@long_name}" => true }
        end
    end

    class ScalarOption < CliOption
        def initialize(name,long_name,default,desc)
            @name = name
            @long_name = long_name
            @desc = desc
            @default = default
        end

        attr_reader :name,:long_name,:desc

        def display_name()
            str = "-#{@name}, --#{@long_name}"
            str << "[#{@default}]" if @default != nil
            str
        end

        def parse(args)
            return :not_match if args.size == 0
            return :not_match if args[0] != "-#{@name}" && args[0] != "--#{@long_name}"

            # 残りの引数が1つ or 次のパラメータが「-」で始まっている場合、省略されているとみなす
            if args.size <= 1 || args[1][0] == '-' then
                if @default != nil then
                    args.shift
                    return { "#{@long_name}" => @default }
                else
                    return :not_match
                end
            else
                val = args[1]
                args.shift 2
                return { "#{@long_name}" => val }
            end
        end
    end

    class SubCommand < CliOption
        def initialize(name,opt,desc)
            @name = name
            @desc = desc
            @opt = opt
        end

        attr_reader :name,:opts

        def desc()
            @desc + "\n" + @opt.to_s.each_line.map{|s| SPACER * INDENT + s}.join("\n")
        end

        def display_name()
            @name
        end

        def parse(args)
            return :not_match if args.size == 0
            return :not_match if args[0] != @name

            args.shift
            sub_opts = @opt.parse(args)

            # sub command 中に知らないオプションがあったとき
            # TODO : 知らないものが出てきた場合、残りを引数として扱う
            return :invalid if args.size != 0

            {'subcommand' => @name,
             'options' => sub_opts}
        end
    end

    class CliBuilder
        def self.create(&b)
            builder = self.new
            builder.instance_eval(&b)
            builder.to_option
        end

        def initialize()
            @opts = []
            @default = {}
        end

        def to_option()
            ComplexOption.new(@opts,@default)
        end

        def switch(name,long_name = name,if_nothing = false,desc)
            @default.merge!({"#{long_name}" => if_nothing })
            @opts.push SwitchOption.new(name,long_name,desc)
        end

        def scalar(name,long_name = name,default = nil,desc)
            @default.merge!({"#{long_name}" => default})
            @opts.push ScalarOption.new(name,long_name,default,desc)
        end

        def sub_cmd(name,desc,&b)
            sub_opts = CliBuilder.create(&b)
            @opts.push SubCommand.new(name,sub_opts,desc)
        end
    end

    Option = CliBuilder.create do
        switch 'v','version','バージョンを表示する。'
        switch 'h','help','このヘルプを表示します。'
        scalar 'u','user','指定したユーザ名で実行する。'
        scalar 't','token','指定したtokenで実行。'

# TODO : 実装する
#        sub_cmd 'config','設定ファイル(.qtcmd)の表示、編集を行う。' do
#            switch 'a','add','設定を追加する'
#            switch 'l','list','設定を一覧表示する'
#        end

        sub_cmd 'push','投稿をQiitaに送信する' do
            switch 'u','update','既存の投稿を更新する'
            scalar 'id','投稿のidを指定する'
            scalar 'h','title','投稿のタイトルを指定する。デフォルトはファイル名'
            switch 'g','gist','Gistに投稿する'
            switch 'w','tweet','Twitterに投稿する'
            switch 'p','private','限定共有にして投稿する'
            scalar 't','tags','タグを指定する ex) --tags "Qiita,Ruby[1.8,1.9]"'
            scalar 'f','file','ファイルを指定する'
        end
    end

    class Cli
        def initialize(args)
            @orig = args
            @args = @orig.clone
            @opts = Option.parse(@args)

            # TODO : .qtcmdファイルを読んでデフォルトのユーザ名、tokenを取得する

            if @opts.class != Hash then
                puts "不正な引数が指定されています。#{args}"
                exit 1
            end
        end

        def invoke()
            case 
            when @orig.size == 0 then help
            when @opts['help'] then help
            when @opts['version'] then version
            when @opts['subcommand'] == 'push' then push
            else exit 0
            end
        end

        def help()
            puts "qtcmd [options] subcommand [args]"
            puts Option.to_s
            exit 0
        end

        def version()
            puts "qtcmd version #{VERSION}"
            exit 0
        end

        def push()
            sub_opts = @opts['options']
            user = @opts['user']
            token = @opts['token']
            file  = sub_opts['file'] # @args[0]

            unless file
                puts "fileが指定されていません"
                exit 1
            end
            unless File.exist?(file)
                puts "#{file}は存在しません"
                exit 1
            end

            unless user
                puts "ユーザが指定されていません"
                exit 1
            end

            unless token
                puts "トークンが指定されていません"
                exit 1
            end

            title  = sub_opts['title'] || File.basename(file,'.*')
            tags   = sub_opts['tags'].split(',').map{|n| {'name' => n}}
            body   = IO.read(file)
            is_private = sub_opts['private']
            gist = sub_opts['gist']
            tweet = sub_opts['tweet']

            api_args = [title,tags,body,is_private,gist,tweet]
            req = QiitaAPI::Request.new(token,user)
            
            if sub_opts['id']
                api_args.unshift sub_opts['id']
                req.patch_item(*api_args)
            else
                req.post_item(*api_args)
            end
        end
    end
end

QtCmd::Cli.new(ARGV).invoke

