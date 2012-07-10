require 'fig/statement'

module Fig; end

# A statement that specifies or modifies a path environment variable, e.g.
# "append", "path", "add" (though those are all synonyms).
class Fig::Statement::Path < Fig::Statement
  # We block single-quotes right now in order to allow for using them for
  # quoting later.
  VALUE_REGEX          = %r< \A [^;:'"<>|\s]+ \z >x
  ARGUMENT_DESCRIPTION =
    %q[The value must look like "NAME=VALUE". VALUE cannot contain any of ";:<>|", double quotes, or whitespace.]

  # Yields on error.
  def self.parse_name_value(combined)
    variable, value = combined.split('=')

    if variable !~ ENVIRONMENT_VARIABLE_NAME_REGEX
      yield
    end

    value = '' if value.nil?
    if value !~ VALUE_REGEX
      yield
    end

    return [variable, value]
  end

  attr_reader :name, :value

  def initialize(line_column, source_description, name, value)
    super(line_column, source_description)

    @name = name
    @value = value
  end

  def unparse(indent)
    "#{indent}append #{name}=#{value}"
  end
end
