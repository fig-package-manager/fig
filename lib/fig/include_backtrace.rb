# coding: utf-8

require 'fig/repository_error'

module Fig; end

# Stack of applied "include" statements.
#
# Keeps track of overrides and can produce package definition stack traces.
#
# Pushing and popping actually happens via instances being held/let go by
# recursive method calls on RuntimeEnvironment.
class Fig::IncludeBacktrace
  attr_reader :overrides

  def initialize(parent, descriptor)
    @parent     = parent
    @descriptor = descriptor
    @overrides  = {}
    @override_statements = {}  # map package_name -> Statement::Override
  end

  def add_override(statement)
    package_name = statement.package_name
    # Don't replace an existing override on the stack
    return if @parent && @parent.get_override(package_name)

    new_version = statement.version
    existing_version = @overrides[package_name]
    if existing_version && existing_version != new_version
      stacktrace = dump_to_string()
      raise Fig::RepositoryError.new(
        "Override #{package_name} version conflict (#{existing_version} vs #{new_version})#{statement.position_string}." + ( stacktrace.empty? ? '' : "\n#{stacktrace}" )
      )
    end

    @overrides[package_name] = new_version
    @override_statements[package_name] = statement
    statement.added_to_environment(true)
  end

  # Returns a version.
  def get_override(package_name, default_version = nil)
    version = @overrides[package_name]
    if version
      statement = @override_statements[package_name]
      statement.referenced(true) if statement
      return version
    end

    if @parent
      result = @parent.get_override(package_name, default_version)
      # If parent provided an override, it will mark its own statement as referenced
      return result
    end
    
    return default_version
  end

  # Prints a stack trace to the IO object.
  def dump(out)
    stack = []
    collect(stack)
    i = 0
    for descriptor in stack
      indent=''
      i.times { indent += '  ' }
      out.puts indent + descriptor.to_string(:use_default_config, :use_description)
      i += 1
    end
  end

  protected

  def dump_to_string()
    string_handle = StringIO.new
    dump(string_handle)
    return string_handle.string
  end

  def collect(stack)
    if @parent
      @parent.collect(stack)
    end

    stack << @descriptor
  end

  # Collect all override statements from this backtrace level and parents
  def collect_override_statements(statements = [])
    if @parent
      @parent.collect_override_statements(statements)
    end

    @override_statements.values.each do |statement|
      statements << statement
    end

    return statements
  end
end
