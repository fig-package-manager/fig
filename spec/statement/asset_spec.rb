# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/statement/archive'
require 'fig/statement/resource'

[Fig::Statement::Archive, Fig::Statement::Resource].each do
  |statement_type|

  describe statement_type do
    describe '.validate_and_process_escapes_in_location()' do
      def test_should_equal_and_should_glob(
        statement_type, original_location, location
      )
        block_message = nil
        location      = location.clone

        tokenized_location =
          statement_type.validate_and_process_escapes_in_location(location) do
            |message| block_message = message
          end

        block_message.should be_nil

        location     = tokenized_location.to_expanded_string
        need_to_glob = ! tokenized_location.single_quoted?

        location.should       == original_location
        need_to_glob.should   be true

        return
      end

      def test_should_equal_and_should_not_glob(
        statement_type, original_location, location
      )
        block_message = nil
        location      = location.clone

        tokenized_location =
          statement_type.validate_and_process_escapes_in_location(location) do
            |message| block_message = message
          end

        location     = tokenized_location.to_expanded_string
        need_to_glob = ! tokenized_location.single_quoted?

        block_message.should  be_nil
        location.should       == original_location
        need_to_glob.should   be false

        return
      end

      # "foo * bar": whitespace and glob character
      [%q<foo * bar>].each do
        |original_location|

        it %Q<does not modify «#{original_location}» and says that it should be globbed> do
          test_should_equal_and_should_glob(
            statement_type, original_location, original_location
          )
        end
        it %Q<strips quotes from «"#{original_location}"» and says that it should be globbed> do
          test_should_equal_and_should_glob(
            statement_type, original_location, %Q<"#{original_location}">
          )
        end

        it %Q<strips quotes from «'#{original_location}'» and says that it should not be globbed> do
          test_should_equal_and_should_not_glob(
            statement_type, original_location, %Q<'#{original_location}'>
          )
        end
      end

      %w< \\ ' >.each do
        |character|

        escaped_location = %Q<foo \\#{character} bar>
        unescaped_location = %Q<foo #{character} bar>
        it %Q<processes escapes from «'#{escaped_location}'» and says that it should not be globbed> do
          test_should_equal_and_should_not_glob(
            statement_type, unescaped_location, %Q<'#{escaped_location}'>
          )
        end
      end

      %w< \\ " >.each do
        |character|

        escaped_location = %Q<foo \\#{character} bar>
        unescaped_location = %Q<foo #{character} bar>
        it %Q<processes escapes from «#{escaped_location}» and says that it should be globbed> do
          test_should_equal_and_should_glob(
            statement_type, unescaped_location, escaped_location
          )
        end
        it %Q<processes escapes from «"#{escaped_location}"» and says that it should be globbed> do
          test_should_equal_and_should_glob(
            statement_type, unescaped_location, %Q<"#{escaped_location}">
          )
        end
      end

      def test_got_error_message(statement_type, location, error_regex)
        block_message = nil

        statement_type.validate_and_process_escapes_in_location(location.dup) do
          |message| block_message = message
        end

        block_message.should =~ error_regex

        return
      end

      def test_contains_bad_escape(statement_type, location)
        test_got_error_message(
          statement_type, location, /contains a bad escape sequence/i
        )

        return
      end

      %w< @ " >.each do
        |character|

        it %Q<says «'foo \\#{character} bar'» isn't allowed> do
          test_contains_bad_escape(statement_type, %Q<'foo \\#{character} bar'>)
        end
      end

      %w< ' 'xxx xxx' '\' '\\ >.each do
        |location|

        it %Q<says «#{location}» has unbalanced quotes> do
          test_got_error_message(
            statement_type, location, /has unbalanced single quotes/i
          )
        end
      end

      %w< " "xxx xxx" "\" "\\ >.each do
        |location|

        it %Q<says «#{location}» has unbalanced quotes> do
          test_got_error_message(
            statement_type, location, /has unbalanced double quotes/i
          )
        end
      end

      %w< xxx'xxx xxx"xxx >.each do
        |location|

        it %Q<says «#{location}» has unescaped quote> do
          test_got_error_message(
            statement_type, location, /unescaped .* quote/i
          )
        end
      end

      %w< \\ xxx\\ >.each do
        |location|

        it %Q<says «#{location}» has incomplete escape> do
          test_got_error_message(statement_type, location, /incomplete escape/i)
        end
      end

      %w< \\n '\\n' "\\n" >.each do
        |location|

        it %Q<says «#{location}» has bad escape> do
          test_got_error_message(statement_type, location, /bad escape/i)
        end
      end

      %w<
        foo\\\\\\\\bar\\\\baz 'foo\\\\\\\\bar\\\\baz' "foo\\\\\\\\bar\\\\baz"
      >.each do
        |original_location|

        it %Q<collapses the backslashes in «#{original_location}»> do
          location           = original_location.clone
          block_message = nil

          tokenized_location =
            statement_type.validate_and_process_escapes_in_location(location) do
              |message| block_message = message
            end

          tokenized_location.to_expanded_string == 'foo\\\\bar\\baz'
          block_message.should                  be_nil
        end
      end
    end
  end
end

# vim: set fileencoding=utf8 :
