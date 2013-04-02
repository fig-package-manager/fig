require 'fig/deparser'
require 'fig/deparser/v1_base'
require 'fig/deparser/v2_base'

module Fig; end
module Fig::Deparser; end

# Handles serializing of statements in the v2 grammar.
class Fig::Deparser::V2
  include Fig::Deparser
  include Fig::Deparser::V1Base
  include Fig::Deparser::V2Base

  def initialize(
    emit_as_input_or_to_be_published_values,
    indent_string = ' ' * 2,
    initial_indent_level = 0
  )
    @emit_as_input_or_to_be_published_values =
      emit_as_input_or_to_be_published_values
    @indent_string        = indent_string
    @initial_indent_level = initial_indent_level

    return
  end

  def grammar_version(statement)
    add_indent

    @text << "grammar v2\n"

    return
  end

  def grammar_description()
    return 'v2'
  end
end
