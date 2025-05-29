# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'English'

require 'fig/command/package_loader'

describe 'Fig' do
  describe 'usage errors: fig' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
    end

    it %q<prints usage message when passed an unknown option> do
      out, err, exit_code =
        fig %w<--no-such-option>, :fork => false, :no_raise_on_error => true
      exit_code.should_not == 0
      err.should =~ / --no-such-option /x
      err.should =~ / usage /xi
      out.should == ''
    end

    describe %q<prints message when no descriptor is specified and> do
      describe %q<there's nothing to do and> do
        it %q<there isn't a package.fig file> do
          out, err, exit_code =
            fig [], :fork => false, :no_raise_on_error => true
          exit_code.should_not == 0
          err.should =~ /nothing to do/i
          out.should == ''
        end

        describe %q<there is a package.fig file> do
          it %q<with no command statement> do
            IO.write(
              "#{FIG_SPEC_BASE_DIRECTORY}/#{Fig::Command::PackageLoader::DEFAULT_PACKAGE_FILE}",
              <<-END_PACKAGE_DOT_FIG
                config default
                end
              END_PACKAGE_DOT_FIG
            )

            out, err, exit_code =
              fig [], :fork => false, :no_raise_on_error => true
            exit_code.should_not == 0
            err.should =~ /nothing to do/i
            out.should == ''
          end

          it %q<with a command statement> do
            IO.write(
              "#{FIG_SPEC_BASE_DIRECTORY}/#{Fig::Command::PackageLoader::DEFAULT_PACKAGE_FILE}",
              <<-END_PACKAGE_DOT_FIG
                config default
                  command "echo foo"
                end
              END_PACKAGE_DOT_FIG
            )

            out, err, exit_code =
              fig [], :fork => false, :no_raise_on_error => true
            exit_code.should_not == 0
            err.should =~ /nothing to do/i
            out.should == ''
          end
        end
      end
    end

    it %q<prints error when extra parameters are given with a package descriptor> do
      out, err, exit_code = fig(
        %w<package/descriptor extra bits>,
        :fork => false,
        :no_raise_on_error => true
      )
      exit_code.should == 1
      err.should =~ / extra /xi
      err.should =~ / bits /xi
      out.should == ''
    end

    it %q<prints error when a package descriptor consists solely of a version> do
      out, err, exit_code =
        fig %w</version>, :fork => false, :no_raise_on_error => true
      exit_code.should == 1
      err.should =~ /package name required/i
      out.should == ''
    end

    it %q<prints error when a package descriptor consists solely of a config> do
      out, err, exit_code =
        fig %w<:config>, :fork => false, :no_raise_on_error => true
      exit_code.should_not == 0
      err.should =~ /package name required/i
      out.should == ''
    end

    it %q<prints error when a package descriptor consists solely of a package> do
      out, err, exit_code =
        fig %w<package>, :fork => false, :no_raise_on_error => true
      exit_code.should_not == 0
      err.should =~ /version required/i
      out.should == ''
    end

    it %q<prints error when a descriptor and --file is specified> do
      out, err, exit_code = fig(
        %w<package/version:default --file some.fig>,
        :fork => false,
        :no_raise_on_error => true
      )
      exit_code.should_not == 0
      err.should =~ /cannot specify both a package descriptor.*and the --file option/i
      out.should == ''
    end

    it %q<prints error when a descriptor contains a config and --config is specified> do
      out, err, exit_code = fig(
        %w<package/version:default --config nondefault>,
        :fork => false,
        :no_raise_on_error => true
      )
      exit_code.should_not == 0
      err.should =~ /Cannot specify both --config and a config in the descriptor/
      out.should == ''
    end

    it %q<prints error when extra parameters are given with a command> do
      out, err, exit_code = fig(
        %w<extra bits -- echo foo>,
        :fork => false,
        :no_raise_on_error => true
      )
      exit_code.should_not == 0
      err.should =~ / extra /xi
      err.should =~ / bits /xi
      out.should == ''
    end

    it %q<prints error when multiple --list-* options are given> do
      out, err, exit_code = fig(
        %w<--list-remote --list-variables>,
        :fork => false,
        :no_raise_on_error => true
      )
      exit_code.should_not == 0
      out.should == ''

      err.should =~ /cannot specify/i
    end

    describe %q<prints error when unknown package is referenced> do
      it %q<without --update> do
        out, err, exit_code = fig(
          %w<no-such-package/version --get PATH>,
          :fork => false,
          :no_raise_on_error => true
        )
        exit_code.should_not == 0
        err.should =~ / no-such-package /x
        out.should == ''
      end

      it %q<with --update> do
        out, err, exit_code = fig(
          %w<no-such-package/version --update --get PATH>,
          :fork => false,
          :no_raise_on_error => true
        )
        exit_code.should_not == 0
        err.should =~ / no-such-package /x
        out.should == ''
      end

      it %q<with --update-if-missing> do
        out, err, exit_code = fig(
            %w<no-such-package/version --update-if-missing --get PATH>,
            :fork => false,
            :no_raise_on_error => true
        )
        exit_code.should_not == 0
        err.should =~ / no-such-package /x
        out.should == ''
      end
    end

    describe %q<prints error when referring to non-existent configuration> do
      it %q<from the command-line as the base package> do
        fig %w<--publish foo/1.2.3 --set FOO=BAR>, :fork => false
        out, err, exit_code = fig(
          %w<foo/1.2.3:non-existent-config --get FOO>,
          :fork => false,
          :no_raise_on_error => true
        )
        exit_code.should_not == 0
        err.should =~ %r< non-existent-config >x
        out.should == ''
      end

      it %q<from the command-line as an included package> do
        fig %w<--publish foo/1.2.3 --set FOO=BAR>, :fork => false
        out, err, exit_code = fig(
          %w<--include foo/1.2.3:non-existent-config --get FOO>,
          :fork => false,
          :no_raise_on_error => true
        )
        exit_code.should_not == 0
        err.should =~ %r< foo/1\.2\.3:non-existent-config >x
        out.should == ''
      end
    end

    it %q<prints error when --include is specified without a package version> do
      out, err, exit_code = fig(
        %w<--include package-without-version --get FOO>,
        :fork => false,
        :no_raise_on_error => true
      )
      exit_code.should_not == 0
      err.should =~ %r< package-without-version >x
      err.should =~ %r<no version specified>i
      out.should == ''
    end

    it %q<prints error when --override is specified without a package version> do
      out, err, exit_code = fig(
        %w<--override package-without-version>,
        :fork => false,
        :no_raise_on_error => true
      )
      exit_code.should_not == 0
      err.should =~ %r< package-without-version >x
      err.should =~ %r<version required>i
      out.should == ''
    end

    it %q<prints error when --override is specified with a package config> do
      out, err, exit_code = fig(
        %w<--override package/version:config-should-not-be-here>,
        :fork => false,
        :no_raise_on_error => true
      )
      exit_code.should_not == 0
      err.should =~ %r< package/version:config-should-not-be-here >x
      err.should =~ %r<config forbidden>i
      out.should == ''
    end

    it %q<prints error when --publish-comment is specified when not publishing> do
      out, err, exit_code = fig(
        %w<--publish-comment whatever>,
        :fork => false,
        :no_raise_on_error => true
      )
      exit_code.should_not == 0
      err.should =~ %r<cannot use --publish-comment when not publishing>i
      out.should == ''
    end

    it %q<prints error when --publish-comment-file is specified when not publishing> do
      out, err, exit_code = fig(
        %w<--publish-comment-file whatever>,
        :fork => false,
        :no_raise_on_error => true
      )
      exit_code.should_not == 0
      err.should =~ %r<cannot use --publish-comment-file when not publishing>i
      out.should == ''
    end

    describe %q<refuses to publish> do
      it %q<a package named "_meta"> do
        out, err, exit_code =
          fig(
            %w<--publish _meta/version --set FOO=BAR>,
            :fork => false,
            :no_raise_on_error => true
          )
        err.should =~ %r< cannot .* _meta >x
        exit_code.should_not == 0
        out.should == ''
      end

      it %q<without a package name> do
        out, err, exit_code = fig(
          %w<--publish --set FOO=BAR>,
          :fork => false,
          :no_raise_on_error => true
        )
        exit_code.should_not == 0
        err.should =~ %r<specify a descriptor>i
        out.should == ''
      end

      it %q<without a version> do
        out, err, exit_code = fig(
          %w<--publish a-package --set FOO=BAR>,
          :fork => false,
          :no_raise_on_error => true
        )
        exit_code.should_not == 0
        err.should =~ %r<version required>i
        out.should == ''
      end

      it %q<when given the --include-file option> do
        IO.write "#{CURRENT_DIRECTORY}/thingy.fig", 'config default end'

        out, err, exit_code = fig(
          [
            '--publish',
            'package/version',
            '--include-file',
            "'#{CURRENT_DIRECTORY}/thingy.fig'",
          ],
          :fork => false,
          :no_raise_on_error => true
        )
        err.should =~ %r< cannot .* include-file >ix
        exit_code.should_not == 0
        out.should == ''
      end

      it %q<a package with an include-file statement> do
        IO.write "#{CURRENT_DIRECTORY}/thingy.fig", 'config default end'

        input = <<-END
          grammar v2
          config default
            include-file '#{CURRENT_DIRECTORY}/thingy.fig'
          end
        END

        out, err, exit_code = fig(
          %w<--publish package/version>,
          input,
          :fork => false,
          :no_raise_on_error => true
        )
        err.should =~ %r< cannot .* include-file >ix
        exit_code.should_not == 0
        out.should == ''
      end

      it %q<a package with an archive of unknown type> do
        archive_file = 'unknown.archive-type'
        IO.write "#{CURRENT_DIRECTORY}/#{archive_file}", ''

        input = <<-END
          grammar v0

          archive #{archive_file}

          config default
          end
        END

        out, err, exit_code = fig(
          %w<--publish package/version>,
          input,
          :fork => false,
          :no_raise_on_error => true
        )

        err.should =~ %r< \b #{ Regexp.escape(archive_file) } \b >ix
        err.should =~ %r< \b unknown [ ] archive [ ] type \b >ix

        exit_code.should_not == 0
        out.should == ''
      end
    end

    it %q<complains about command-line substitution of unreferenced packages> do
      fig %w<--publish a-package/a-version --set FOO=BAR>, :fork => false
      out, err, exit_code =
        fig %w<-- echo @a-package>, :fork => false, :no_raise_on_error => true
      exit_code.should_not == 0
      err.should =~ %r<\ba-package\b.*has not been referenced>
      out.should == ''
    end

    %w< --archive --resource >.each do
      |option|

      it %Q<warns about #{option} when not publishing> do
        out, err =
          fig ['--get', 'some_variable', option, 'some-asset'], :fork => false
        err.should =~ /#{option}/
        err.should =~ /\bsome-asset\b/
      end
    end

    describe %q<prints error when attempting a remote operation and required URLs are missing or invalid> do
      it %q<FIG_DOWNLOAD_URL not defined> do
        begin
          # Make sure all URL env vars are unset
          ENV.delete('FIG_REMOTE_URL')
          ENV.delete('FIG_DOWNLOAD_URL')
          ENV.delete('FIG_PUBLISH_URL')

          out, err, exit_code =
            fig %w<--list-remote>, :fork => false, :no_raise_on_error => true

          # Error should mention the missing FIG_DOWNLOAD_URL
          err.should =~ %r<FIG_DOWNLOAD_URL>
          out.should == ''
          exit_code.should_not == 0
        ensure
          # Restore default test configuration
          ENV['FIG_DOWNLOAD_URL'] = FIG_DOWNLOAD_URL 
          ENV['FIG_PUBLISH_URL'] = FIG_PUBLISH_URL
        end
      end

      it %q<FIG_DOWNLOAD_URL empty> do
        begin
          # Clear all URLs, but set download to empty
          ENV.delete('FIG_REMOTE_URL')
          ENV['FIG_DOWNLOAD_URL'] = ''
          ENV.delete('FIG_PUBLISH_URL')

          out, err, exit_code =
            fig %w<--list-remote>, :fork => false, :no_raise_on_error => true

          err.should =~ %r<FIG_DOWNLOAD_URL>
          out.should == ''
          exit_code.should_not == 0
        ensure
          # Restore default test configuration
          ENV['FIG_DOWNLOAD_URL'] = FIG_DOWNLOAD_URL 
          ENV['FIG_PUBLISH_URL'] = FIG_PUBLISH_URL
        end
      end

      it %q<FIG_DOWNLOAD_URL all whitespace> do
        begin
          # Clear all URLs, but set download to whitespace
          ENV.delete('FIG_REMOTE_URL')
          ENV['FIG_DOWNLOAD_URL'] = " \n\t"
          ENV.delete('FIG_PUBLISH_URL')

          out, err, exit_code =
            fig %w<--list-remote>, :fork => false, :no_raise_on_error => true

          # With whitespace URLs, error is about bad URI format
          err.should =~ %r<FIG_DOWNLOAD_URL>
          out.should == ''
          exit_code.should_not == 0
        ensure
          # Restore default test configuration
          ENV['FIG_DOWNLOAD_URL'] = FIG_DOWNLOAD_URL 
          ENV['FIG_PUBLISH_URL'] = FIG_PUBLISH_URL
        end
      end
      
      it %q<FIG_REMOTE_URL set but new URLs missing> do
        begin
          # Set remote URL but not the new ones
          ENV['FIG_REMOTE_URL'] = "file:///some/path"
          ENV.delete('FIG_DOWNLOAD_URL')
          ENV.delete('FIG_PUBLISH_URL')

          out, err, exit_code =
            fig %w<--list-remote>, :fork => false, :no_raise_on_error => true

          # Error should mention both old and new URLs
          err.should =~ %r<FIG_REMOTE_URL is set but FIG_DOWNLOAD_URL and\/or FIG_PUBLISH_URL are missing>
          out.should == ''
          exit_code.should_not == 0
        ensure
          # Restore default test configuration
          ENV.delete('FIG_REMOTE_URL')
          ENV['FIG_DOWNLOAD_URL'] = FIG_DOWNLOAD_URL 
          ENV['FIG_PUBLISH_URL'] = FIG_PUBLISH_URL
        end
      end
    end
  end
end
