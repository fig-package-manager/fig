# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/application_configuration'
require 'fig/not_yet_parsed_package'
require 'fig/package_descriptor'
require 'fig/package_parse_error'
require 'fig/parser'

describe 'Parser' do
  def new_configuration
    application_configuration = Fig::ApplicationConfiguration.new

    application_configuration.base_whitelisted_url = 'http://example/'
    application_configuration.remote_consume_url = 'http://example/'
    application_configuration.remote_publish_url = 'http://example/'

    return application_configuration
  end

  def test_no_parse_exception(fig_input)
    application_configuration = new_configuration

    unparsed_package = Fig::NotYetParsedPackage.new
    unparsed_package.descriptor         =
      Fig::PackageDescriptor.new('package_name', '0.1.1', nil)
    unparsed_package.working_directory  =
      unparsed_package.include_file_base_directory =
      'foo_directory'
    unparsed_package.source_description = 'source description'
    unparsed_package.unparsed_text      = fig_input

    package = Fig::Parser.new(application_configuration, false).parse_package(
      unparsed_package
    )
    # Got no exception.

    return package
  end

  def test_error(fig_input, error_class, message_pattern)
    application_configuration = new_configuration

    unparsed_package = Fig::NotYetParsedPackage.new
    unparsed_package.descriptor         =
      Fig::PackageDescriptor.new('package_name', '0.1.1', nil)
    unparsed_package.working_directory  =
      unparsed_package.include_file_base_directory =
      'foo_directory'
    unparsed_package.source_description = 'source description'
    unparsed_package.unparsed_text      = fig_input

    expect {
      Fig::Parser.new(application_configuration, false).parse_package(
        unparsed_package
      )
    }.to raise_error(error_class, message_pattern)

    return
  end

  def test_user_input_error(fig_input, message_pattern)
    test_error(fig_input, Fig::UserInputError, message_pattern)

    return
  end

  def test_package_parse_error(
    fig_input, message_pattern = /source description/
  )
    test_error(fig_input, Fig::PackageParseError, message_pattern)

    return
  end

  describe 'base syntax' do
    it 'throws the correct exception on syntax error' do
      application_configuration = new_configuration

      unparsed_package = Fig::NotYetParsedPackage.new
      unparsed_package.descriptor         =
        Fig::PackageDescriptor.new('package_name', '0.1.1', nil)
      unparsed_package.working_directory  =
        unparsed_package.include_file_base_directory =
        'foo_directory'
      unparsed_package.source_description = 'source description'
      unparsed_package.unparsed_text      = <<-END
        this is invalid syntax
      END

      expect {
        Fig::Parser.new(application_configuration, false).parse_package(
          unparsed_package
        )
      }.to raise_error(
        Fig::PackageParseError
      )
    end

    it 'assigns the correct line and column number to Statement objects.' do
      fig_package=<<-FIG_PACKAGE

        # Blank line above to ensure that we can handle starting whitespace.
        resource http://example/is/awesome.tgz

            # Indentation in here is weird to test we get things right.

            # Also, we need a comment in here to make sure that cleaning them out
            # does not affect values for statements.

         archive http://svpsvn/my/repo/is/cool.jar

        config default
                include package/some-version

           set VARIABLE=VALUE
                  end
      FIG_PACKAGE

      unparsed_package = Fig::NotYetParsedPackage.new
      unparsed_package.descriptor         =
        Fig::PackageDescriptor.new('package_name', '0.1.1', nil)
      unparsed_package.working_directory  =
        unparsed_package.include_file_base_directory =
        'foo_directory'
      unparsed_package.source_description = 'source description'
      unparsed_package.unparsed_text      = fig_package

      application_configuration = new_configuration
      package = Fig::Parser.new(application_configuration, false).parse_package(
        unparsed_package
      )

      package.walk_statements do
        |statement|

        case statement
          when Fig::Statement::Resource
            statement.line.should == 3
            statement.column.should == 9
          when Fig::Statement::Archive
            statement.line.should == 10
            statement.column.should == 10
          when Fig::Statement::Configuration
            statement.line.should == 12
            statement.column.should == 9
          when Fig::Statement::Include
            statement.line.should == 13
            statement.column.should == 17
          when Fig::Statement::Set
            statement.line.should == 15
            statement.column.should == 12
        end
      end
    end
  end

  describe 'validating URLs' do
    it 'passes valid, whitelisted ones' do
      fig_package=<<-FIG_PACKAGE
        resource http://example/is/awesome.tgz

        archive http://svpsvn/my/repo/is/cool.jar
      FIG_PACKAGE
      application_configuration = new_configuration
      application_configuration.push_dataset( { 'url whitelist' => 'http://svpsvn/' } )

      unparsed_package = Fig::NotYetParsedPackage.new
      unparsed_package.descriptor         =
        Fig::PackageDescriptor.new('package_name', '0.1.1', nil)
      unparsed_package.working_directory  =
        unparsed_package.include_file_base_directory =
        'foo_directory'
      unparsed_package.source_description = 'source description'
      unparsed_package.unparsed_text      = fig_package

      package = Fig::Parser.new(application_configuration, false).parse_package(
        unparsed_package
      )
      package.should_not == nil
    end

    it 'rejects non-whitelisted ones' do
      fig_package=<<-FIG_PACKAGE
        resource http://evil_url/is/bad.tgz

        archive http://evil_repo/my/repo/is/bad.jar
      FIG_PACKAGE
      application_configuration = new_configuration
      application_configuration.push_dataset( { 'url whitelist' => 'http://svpsvn/' } )

      unparsed_package = Fig::NotYetParsedPackage.new
      unparsed_package.descriptor         =
        Fig::PackageDescriptor.new('package_name', '0.1.1', nil)
      unparsed_package.working_directory  =
        unparsed_package.include_file_base_directory =
        'foo_directory'
      unparsed_package.source_description = 'source description'
      unparsed_package.unparsed_text      = fig_package

      exception = nil
      begin
        package =
          Fig::Parser.new(application_configuration, false).parse_package(
            unparsed_package
          )
      rescue Fig::URLAccessDisallowedError => exception
      end
      exception.should_not == nil
      exception.urls.should =~ %w<http://evil_url/is/bad.tgz http://evil_repo/my/repo/is/bad.jar>
      exception.descriptor.name.should == 'package_name'
      exception.descriptor.version.should == '0.1.1'
    end
  end

  describe 'command statements' do
    %w< 0 1 >.each do
      |version|

      command_terminator = version.to_i == 0 ? '' : ' end'
      describe %Q<in the v#{version} grammar> do
        it 'reject multiple commands in config file' do
          input = <<-"END_PACKAGE"
            grammar v#{version}
            config default
              command "echo foo"#{command_terminator}
              command "echo bar"#{command_terminator}
            end
          END_PACKAGE

          test_user_input_error(
            input,
            /found a second "command" statement within a "config" block/i
          )
        end

        it 'accept multiple configs, each with a single command' do
          test_no_parse_exception(<<-"END_PACKAGE")
            grammar v#{version}
            config default
              command "echo foo"#{command_terminator}
            end
            config another
              command "echo bar"#{command_terminator}
            end
          END_PACKAGE
        end

        it 'reject multiple configs where one has multiple commands' do
          input = <<-"END_PACKAGE"
            grammar v#{version}
            config default
              command "echo foo"#{command_terminator}
            end
            config another
              command "echo bar"#{command_terminator}
              command "echo baz"#{command_terminator}
            end
          END_PACKAGE

          test_user_input_error(
            input,
            /found a second "command" statement within a "config" block/i
          )
        end
      end
    end
  end

  describe 'path statements' do
    {
      ';'  => ';',
      ':'  => ':',
      '"'  => '"',
      '<'  => '<',
      '>'  => '>',
      '|'  => '|',
      ' '  => ' ',
      '\t' => "\t",
      '\r' => "\r",
      '\n' => "\n"
    }.each do
      |display, character|

      it %Q<reject "#{display}" in a PATH component in the v0 grammar> do
        input = <<-"END_PACKAGE"
          grammar v0
          config default
            append PATH_VARIABLE=#{character}
          end
        END_PACKAGE

        test_user_input_error(
          input, /(?i:invalid append statement).*\bPATH_VARIABLE\b/
        )
      end

      it %Q<accept "#{display}" in a PATH component in the v1 grammar> do
        right_hand_side = nil
        if character == '"' or character =~ /\s/
          right_hand_side = %Q<'#{character}'>
        else
          right_hand_side = character
        end

        test_no_parse_exception(<<-"END_PACKAGE")
          grammar v1
          config default
            append PATH_VARIABLE=#{right_hand_side}
          end
        END_PACKAGE
      end
    end
  end

  %w< archive resource >.each do
    |asset_type|

    describe "#{asset_type} statements" do
      %w< ' " >.each do
        |character|

        %w< 0 1 >.each do
          |version|

          it %Q<produce a parse error with unescaped «#{character}» in a URL in the v#{version} grammar> do
            input = <<-"END_PACKAGE"
              grammar v#{version}
              #{asset_type} #{character}
            END_PACKAGE

            test_package_parse_error(input)
          end
        end
      end

      %w[ @ < > | ].each do
        |character|


        it %Q<produce a parse error with «#{character}» in a URL in the v0 grammar> do
          input = <<-"END_PACKAGE"
            #{asset_type} #{character}
          END_PACKAGE

          test_package_parse_error(input)
        end

        %w< 1 >.each do
          |version|

          it %Q<handles «#{character}» in a URL in the v#{version} grammar> do
            package = test_no_parse_exception(<<-"END_PACKAGE")
              grammar v#{version}
              #{asset_type} foo#{character}bar
              config default
              end
            END_PACKAGE

            url =
              [package.archive_locations, package.resource_locations].flatten[0]
            url.should == "foo#{character}bar"
          end
        end
      end

      it %q<handles octothorpes in a URL in the v1 grammar> do
        package = test_no_parse_exception(<<-"END_PACKAGE")
          grammar v1
          #{asset_type} 'foo#bar'
          config default
          end
        END_PACKAGE

        url = [package.archive_locations, package.resource_locations].flatten[0]
        url.should == 'foo#bar'
      end

      describe %Q<handles plus signs in the path (e.g. for C++ libraries)> do
        %w< 0 1 >.each do
          |version|

          it %Q<in the v#{version} grammar> do
            test_no_parse_exception(<<-"END_PACKAGE")
              grammar v#{version}
              #{asset_type} testlib++.whatever
              config default
                append LIBPATH=@/testlib++
              end
            END_PACKAGE
          end
        end
      end
    end
  end
end

# vim: set fileencoding=utf8 :
