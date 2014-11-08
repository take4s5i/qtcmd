
require 'spec_helper'
require 'qtcmd'

describe 'QtCmd' do
    describe 'SwitchOption' do
        let(:opt)  { QtCmd::SwitchOption.new('h','help','test') }

        it '名前と説明が取得できること' do
            expect(opt.name).to eq 'h'
            expect(opt.long_name).to eq 'help'
            expect(opt.desc).to eq 'test'
        end

        it 'nameと同じ引数の場合、parse出来ること' do
            args = ['-h','rest']
            hash = {'help' => true }

            expect(opt.parse(args)).to eq hash
            expect(args).to eq ['rest']
        end

        it 'nameと違う引数の場合、parseされないこと' do
            args = ['-x','rest']

            expect(opt.parse(args)).to eq :not_match
            expect(args).to eq ['-x','rest']
        end

        it 'long_nameと同じ引数の場合、parse出来ること' do
            args = ['--help','rest']
            hash = {'help' => true }

            expect(opt.parse(args)).to eq hash
            expect(args).to eq ['rest']
        end

        it 'long_nameと違う引数の場合、parseされないこと' do
            args = ['--hoge','rest']

            expect(opt.parse(args)).to eq :not_match
            expect(args).to eq ['--hoge','rest']
        end
    end

    describe 'ScalarOption' do
        context 'defaultが設定されていない場合' do
            let(:opt)  { QtCmd::ScalarOption.new('n','name',nil,'test') }

            it '名前と説明が取得できること' do
                expect(opt.name).to eq 'n'
                expect(opt.long_name).to eq 'name'
                expect(opt.desc).to eq 'test'
            end

            it 'nameと同じ引数の場合、parse出来ること' do
                args = ['-n','takesi','rest']
                hash = {'name' => 'takesi' }

                expect(opt.parse(args)).to eq hash
                expect(args).to eq ['rest']
            end

            it 'nameと違う引数の場合、parseされないこと' do
                args = ['-x','takesi','rest']

                expect(opt.parse(args)).to eq :not_match
                expect(args).to eq ['-x','takesi','rest']
            end

            it 'long_nameと同じ引数の場合、parse出来ること' do
                args = ['--name','takesi','rest']
                hash = {'name' => 'takesi' }

                expect(opt.parse(args)).to eq hash
                expect(args).to eq ['rest']
            end

            it 'long_nameと違う引数の場合、parseされないこと' do
                args = ['--hoge','takesi','rest']

                expect(opt.parse(args)).to eq :not_match
                expect(args).to eq ['--hoge','takesi','rest']
            end

            it '値なしで次のパラメータが設定されていた場合、parseされないこと' do
                args = ['--name','-t','rest']

                expect(opt.parse(args)).to eq :not_match
                expect(args).to eq ['--name','-t','rest']
            end

            it '最後のパラメータだった場合、parseされないこと' do
                args = ['--name']

                expect(opt.parse(args)).to eq :not_match
                expect(args).to eq ['--name']
            end
        end

        context 'defaultが設定されている場合' do
            let(:opt)  { QtCmd::ScalarOption.new('n','name',false,'test') }

            it '名前と説明が取得できること' do
                expect(opt.name).to eq 'n'
                expect(opt.long_name).to eq 'name'
                expect(opt.desc).to eq 'test'
            end

            it 'nameと同じ引数の場合、parse出来ること' do
                args = ['-n','takesi','rest']
                hash = {'name' => 'takesi' }

                expect(opt.parse(args)).to eq hash
                expect(args).to eq ['rest']
            end

            it 'nameと違う引数の場合、parseされないこと' do
                args = ['-x','takesi','rest']

                expect(opt.parse(args)).to eq :not_match
                expect(args).to eq ['-x','takesi','rest']
            end

            it 'long_nameと同じ引数の場合、parse出来ること' do
                args = ['--name','takesi','rest']
                hash = {'name' => 'takesi' }

                expect(opt.parse(args)).to eq hash
                expect(args).to eq ['rest']
            end

            it 'long_nameと違う引数の場合、parseされないこと' do
                args = ['--hoge','takesi','rest']

                expect(opt.parse(args)).to eq :not_match
                expect(args).to eq ['--hoge','takesi','rest']
            end

            it '値なしで次のパラメータが設定されていた場合、defaultが設定されていること' do
                args = ['--name','-t','rest']
                hash = { 'name' => false }

                expect(opt.parse(args)).to eq hash
                expect(args).to eq ['-t','rest']
            end

            it '最後のパラメータだった場合、defaultが設定されていること' do
                args = ['--name']
                hash = { 'name' => false }

                expect(opt.parse(args)).to eq hash
                expect(args).to eq []
            end
        end
    end

    describe 'SubCommand' do
        let(:opt) do
            opts =[]
            opts.push QtCmd::SwitchOption.new('1','oneline','test')
            opts.push QtCmd::ScalarOption.new('r','ref','HEAD','test')
            default = {'oneline' => false,
                       'ref' => 'HEAD' }
            opt  = QtCmd::ComplexOption.new(opts,default)
            QtCmd::SubCommand.new('log',opt,'test')
        end

        it 'subcommandより前に知らないオプションがあったら、停止すること' do
            args = ['-x','log','-1']

            expect(opt.parse(args)).to eq :not_match
            expect(args).to eq ['-x','log','-1']
        end

        it 'subcommandがすべてのオプションを使いきらなかった場合、停止すること' do
            args = ['log','-1','-x']

            expect(opt.parse(args)).to eq :invalid
            expect(args).to eq ['-x']
        end

        it 'subcommandにオプションが設定されない場合、defaultがが設定されること' do
            args = ['log']
            hash = {'subcommand' => 'log',
                    'options' => {'oneline' => false,
                                  'ref' => 'HEAD'}}

            expect(opt.parse(args)).to eq hash
            expect(args).to eq []
        end

        it 'subcommandがすべてのオプションを使いきった場合、parse出来ること' do
            args = ['log','--ref','develop']
            hash = {'subcommand' => 'log',
                    'options' => {'oneline' => false,
                                  'ref' => 'develop'}}

            expect(opt.parse(args)).to eq hash
            expect(args).to eq []
        end
    end
    
    describe 'ComplexOption & CliBuilder' do
        context 'subcommandなしの場合' do
            let(:opt) do
                QtCmd::CliBuilder.create do
                    switch 'h','help','test'
                    scalar 'n','name','takesi','test'
                end
            end

            it 'オプションが呼ばれなかった場合にはdefaultで作られていること' do
                args = []
                hash = { 'help' => false,
                         'name' => 'takesi' }

                expect(opt.parse(args)).to eq hash
                expect(args).to eq []
            end

            it '知らないオプションが来ると、そこで停止すること' do
                args = ['-h','-x','--name','sigeru']

                expect(opt.parse(args)).to eq :invalid
                expect(args).to eq ['-x','--name','sigeru']
            end
        end

        context 'subcommandありの場合' do
            let(:opt) do
                QtCmd::CliBuilder.create do
                    switch 'h','help','test'
                    scalar 'n','name','takesi','test'

                    sub_cmd 'log','test' do
                        switch '1','oneline','test'
                        scalar 'r','ref','HEAD','test'
                    end

                    sub_cmd 'add','test' do
                        switch 'f','force','test'
                        scalar 'e','exclude','test'
                    end
                end
            end

            it 'subcommandがなかった場合、停止すること' do
                args = ['-h','hoge']

                expect(opt.parse(args)).to eq :invalid
                expect(args).to eq ['hoge']
            end

            it 'logサブコマンドにマッチした場合、addサブコマンドはparseされないこと' do
                args = ['-h','log','-1','add']

                expect(opt.parse(args)).to eq :invalid
                expect(args).to eq ['add']
            end

            it 'logサブコマンドがparse出来た場合、オプションのhashに"add"はいないこと' do
                args = ['-h','log','-1']
                hash = {'help' => true,
                        'name' => 'takesi',
                        'subcommand' => 'log',
                        'options'  => { 'oneline' => true,
                                        'ref' => 'HEAD' }}

                expect(opt.parse(args)).to eq hash
                expect(args).to eq []
            end
        end
    end
end

