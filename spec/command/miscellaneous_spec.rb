require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/command/package_loader'

describe 'Fig' do
  before(:each) do
    clean_up_test_environment
    set_up_test_environment
  end

  it 'ignores comments' do
    input = <<-END
      # Some comment
      config default
        set FOO=BAR # Another comment
      end
    END
    fig('--get FOO', input)[0].should == 'BAR'
  end

  describe '--file' do
    it 'reads from the value' do
      dot_fig_file = "#{FIG_SPEC_BASE_DIRECTORY}/file-option-test.fig"
      write_file(dot_fig_file, <<-END)
        config default
          set FOO=BAR
        end
      END
      fig("--file #{dot_fig_file} --get FOO")[0].should == 'BAR'
    end

    it 'complains about the value not existing' do
      out, err, exit_code =
        fig("--file does-not-exist --get FOO", :no_raise_on_error => true)
      out.should == ''
      err.should =~ /does-not-exist/
      exit_code.should_not == 0
    end
  end

  it 'ignores package.fig with the --no-file option' do
    dot_fig_file =
      "#{FIG_SPEC_BASE_DIRECTORY}/#{Fig::Command::PackageLoader::DEFAULT_FIG_FILE}"
    write_file(dot_fig_file, <<-END)
      config default
        set FOO=BAR
      end
    END
    fig('--no-file --get FOO')[0].should == ''
  end

  it 'complains about conflicting package versions' do
    fig('--publish foo/1.2.3 --set VARIABLE=VALUE')
    fig('--publish foo/4.5.6 --set VARIABLE=VALUE')

    out, err, exit_code = fig(
      '--update --include foo/1.2.3 --include foo/4.5.6',
      :no_raise_on_error => true
    )
    exit_code.should_not == 0
    err.should =~ /version mismatch for package foo/i
  end

  it 'prints the version number' do
    %w/-v --version/.each do |option|
      (out, err, exitstatus) = fig(option)
      exitstatus.should == 0
      err.should == ''
      out.should =~ / \d+ \. \d+ \. \d+ /x
    end
  end

  it 'emits help' do
    %w/-? -h --help/.each do |option|
      (out, err, exitstatus) = fig(option)
      exitstatus.should == 0
      err.should == ''
      out.should =~ / Usage: /x
      out.should =~ / \b fig \b /x
      out.should =~ / --help \b /x
      out.should =~ / --force \b /x
      out.should =~ / --update \b /x
      out.should =~ / --set \b /x
    end
  end

  it 'emits options' do
    (out, err, exitstatus) = fig('--options')
    exitstatus.should == 0
    err.should == ''
    out.should =~ / options: /ix
    out.should =~ / --help \b /x
    out.should =~ / --options \b /x
  end
end
