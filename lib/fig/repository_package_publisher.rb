# coding: utf-8

require 'fileutils'
require 'etc'
require 'set'
require 'socket'
require 'tmpdir'

require 'fig/version'
require 'fig/at_exit'
require 'fig/external_program'
require 'fig/file_not_found_error'
require 'fig/logging'
require 'fig/not_yet_parsed_package'
require 'fig/package_cache'
require 'fig/package_definition_text_assembler'
require 'fig/package_descriptor'
require 'fig/package_parse_error'
require 'fig/parser'
require 'fig/repository'
require 'fig/repository_error'
require 'fig/statement/archive'
require 'fig/statement/grammar_version'
require 'fig/statement/resource'
require 'fig/statement/synthetic_raw_text'
require 'fig/url'

module Fig; end

# Handles package publishing for the Repository.
class Fig::RepositoryPackagePublisher
  attr_writer :application_configuration
  attr_writer :options
  attr_writer :operating_system
  attr_writer :publish_listeners
  attr_writer :descriptor
  attr_writer :source_package
  attr_writer :was_forced
  attr_writer :base_temp_dir
  attr_writer :runtime_for_package
  attr_writer :local_directory_for_package
  attr_writer :remote_directory_for_package
  attr_writer :local_fig_file_for_package
  attr_writer :remote_fig_file_for_package
  attr_writer :local_only

  def initialize()
    @text_assembler =
      Fig::PackageDefinitionTextAssembler.new :emit_as_to_be_published

    return
  end

  def package_statements=(statements)
    @text_assembler.add_input(statements)
  end

  def publish_package()
    derive_publish_metadata()

    temp_dir = publish_temp_dir()
    @operating_system.delete_and_recreate_directory(temp_dir)
    @operating_system.delete_and_recreate_directory(
      @local_directory_for_package
    )
    @operating_system.delete_and_recreate_directory(@runtime_for_package)

    fig_file = File.join(temp_dir, Fig::Repository::PACKAGE_FILE_IN_REPO)
    content, published_package =
      derive_definition_file_and_create_resource_archive
    @operating_system.write(fig_file, content)

    publish_package_contents
    if not @local_only
      @operating_system.upload(fig_file, @remote_fig_file_for_package)
    end
    @operating_system.copy(fig_file, @local_fig_file_for_package)

    notify_listeners

    FileUtils.rm_rf(temp_dir)

    check_published_environment_variables published_package

    return true
  end

  private

  def derive_publish_metadata()
    @publish_time  = Time.now()
    @publish_login = derive_login()
    @publish_host  = Socket.gethostname()

    return
  end

  def derive_login()
    # Etc.getpwuid() returns nil on Windows, but Etc.getlogin() will return the
    # wrong result on some systems if you su(1) to a different user.

    password_entry = nil

    begin
      password_entry = Etc.getpwuid()
    rescue ArgumentError
      # This should come from
      # https://github.com/ruby/ruby/blob/de5e6ca2b484dc19d007ed26b2a923a9a4b34f77/ext/etc/etc.c#L191,
      # which we will silently fall back to .getlogin() for.
    end

    if password_entry and password_entry.name
      return password_entry.name
    end

    return Etc.getlogin()
  end

  def derive_definition_file_and_create_resource_archive()
    add_package_metadata_comments()
    assemble_output_statements_and_accumulate_assets()
    validate_asset_names()
    create_resource_archive()
    add_unparsed_text()

    file_content, explanations = @text_assembler.assemble_package_definition()
    if Fig::Logging.info?
      explanations.each {|explanation| Fig::Logging.info explanation}
    end

    to_be_published_package = nil
    begin
      unparsed_package = Fig::NotYetParsedPackage.new
      unparsed_package.descriptor         = @descriptor
      unparsed_package.working_directory  =
        unparsed_package.include_file_base_directory =
        @runtime_for_package
      unparsed_package.source_description = '<package to be published>'
      unparsed_package.unparsed_text      = file_content

      to_be_published_package =
        Fig::Parser.new(nil, false).parse_package(unparsed_package)
    rescue Fig::PackageParseError => error
      raise \
        "Bug in code! Could not parse package definition to be published.\n" +
        "#{error}\n\nGenerated contents:\n#{file_content}"
    end

    return file_content, to_be_published_package
  end

  def add_package_metadata_comments()
    add_publish_comment

    @text_assembler.add_header(
      %Q<# Publishing information for #{@descriptor.to_string()}:>
    )
    @text_assembler.add_header %q<#>

    @text_assembler.add_header(
      %Q<#     Time: #{@publish_time} (epoch: #{@publish_time.to_i()})>
    )

    @text_assembler.add_header %Q<#     User: #{@publish_login}>
    @text_assembler.add_header %Q<#     Host: #{@publish_host}>
    @text_assembler.add_header %Q<#     O/S:  #{derive_platform_description}>

    sanitized_argv = ARGV.map {|arg| arg.gsub "\n", '\\n'}
    @text_assembler.add_header %Q<#     Args: "#{sanitized_argv.join %q[", "]}">

    @text_assembler.add_header %Q<#     Fig:  v#{Fig::VERSION}>

    add_environment_variables_to_package_metadata
    add_version_control_to_package_metadata

    @text_assembler.add_header %Q<\n>

    return
  end

  def add_publish_comment
    return if not @options.publish_comment and not @options.publish_comment_path

    if @options.publish_comment
      comment = @options.publish_comment
      comment = comment.strip.gsub(/[ \t]*\n/, "\n# ").gsub(/^#[ ]+\n/, "#\n")
      @text_assembler.add_header %Q<# #{comment}>
      @text_assembler.add_header %q<#>
    end

    if @options.publish_comment_path
      begin
        comment = IO.read(
          @options.publish_comment_path, :external_encoding => Encoding::UTF_8,
        )
        comment = comment.strip.gsub(/[ \t]*\n/, "\n# ").gsub(/^#[ ]+\n/, "#\n")
      rescue Errno::ENOENT
        Fig::Logging.fatal(
          %Q<Comment file "#{@options.publish_comment_path}" does not exist.>
        )
        raise Fig::RepositoryError.new
      rescue Errno::EACCES
        Fig::Logging.fatal(
          %Q<Could not read comment file "#{@options.publish_comment_path}".>
        )
        raise Fig::RepositoryError.new
      end

      @text_assembler.add_header %Q<# #{comment}>
      @text_assembler.add_header %q<#>
    end

    @text_assembler.add_header %q<#>

    return
  end

  def derive_platform_description
    host_os = RbConfig::CONFIG['host_os']

    return host_os if host_os !~ /linux|darwin/i

    if host_os =~ /darwin/i
      product_name = %x/sw_vers -productName/
      product_version = %x/sw_vers -productVersion/
      return product_name.strip + ' ' + product_version.strip
    end

    linux_distribution = %x/lsb_release --description --short/
    linux_distribution.chomp!
    linux_distribution.gsub!(/\A " (.*) " \z/x, '\1')

    return linux_distribution
  end

  def add_environment_variables_to_package_metadata()
    variables = @application_configuration[
      'environment variables to include in comments in published packages'
    ]
    return if ! variables || variables.empty?

    @text_assembler.add_header %q<#>
    @text_assembler.add_header %q<# Values of some environment variables at time of publish:>
    @text_assembler.add_header %q<#>
    variables.each do
      |variable|

      value = ENV[variable]
      if value.nil?
        value = ' was unset.'
      else
        value = "=#{value}"
      end

      @text_assembler.add_header %Q<#     #{variable}#{value}>
    end

    return
  end

  def add_version_control_to_package_metadata()
    return if @options.suppress_vcs_comments_in_published_packages?

    add_subversion_metadata_to_package_metadata()
    add_git_metadata_to_package_metadata()

    return
  end

  def add_subversion_metadata_to_package_metadata()
    output = get_subversion_working_directory_info
    return if not output =~ /^URL: +(.*\S)\s*$/
    url = $1

    revision = ''
    if output =~ /^Revision: +(\S+)\s*$/
      revision = ", revision #{$1}"
    end

    @text_assembler.add_header %q<#>
    @text_assembler.add_header(
      %Q<# Publish happened in a Subversion working directory from\n# #{url}#{revision}.>
    )

    return
  end

  def get_subversion_working_directory_info()
    executable =
      get_version_control_executable('FIG_SVN_EXECUTABLE', 'svn') or return
    return run_version_control_command(
      [executable, 'info'], 'Subversion', 'FIG_SVN_EXECUTABLE'
    )
  end

  def run_version_control_command(command, version_control_name, variable)
    begin
      output, errors, result = Fig::ExternalProgram.capture command
    rescue Errno::ENOENT => error
      Fig::Logging.warn(
        %Q<Could not run "#{command.join ' '}": #{error.message}. Set #{variable} to the path to use for #{version_control_name} or to the empty string to suppress #{version_control_name} support.>
      )
      return
    end

    if result && ! result.success?
      Fig::Logging.debug(
        %Q<Could not run "#{command.join ' '}": #{result}: #{errors}>
      )

      return
    end

    return output
  end

  def get_version_control_executable(variable, default)
    executable = ENV[variable]
    if ! executable || executable.empty? || executable =~ /\A\s*\z/
      return if ENV.include? variable
      return default
    end

    return executable
  end

  def add_git_metadata_to_package_metadata()
    url = get_git_origin_url or return
    url.strip!
    return if url.empty?

    branch = get_git_branch
    if branch.nil?
      branch = ''
    else
      branch = ", branch #{branch}"
    end
    sha1 = get_git_sha1
    if sha1.nil?
      sha1 = ''
    else
      sha1 = ",\n# SHA1 #{sha1}"
    end

    @text_assembler.add_header %q<#>
    @text_assembler.add_header(
      %Q<# Publish happened in a Git working directory from\n# #{url}#{branch}#{sha1}.>
    )

    return
  end

  def get_git_origin_url()
    executable =
      get_version_control_executable('FIG_GIT_EXECUTABLE', 'git') or return
    return run_version_control_command(
      [executable, 'config', '--get', 'remote.origin.url'],
      'Git',
      'FIG_GIT_EXECUTABLE'
    )
  end

  def get_git_branch()
    executable =
      get_version_control_executable('FIG_GIT_EXECUTABLE', 'git') or return
    reference = run_version_control_command(
      [executable, 'rev-parse', '--abbrev-ref=strict', 'HEAD'],
      'Git',
      'FIG_GIT_EXECUTABLE'
    )
    return if reference.nil?

    reference.strip!
    return if reference.empty?

    return reference
  end

  def get_git_sha1()
    executable =
      get_version_control_executable('FIG_GIT_EXECUTABLE', 'git') or return
    reference = run_version_control_command(
      [executable, 'rev-parse', 'HEAD'], 'Git', 'FIG_GIT_EXECUTABLE'
    )
    return if reference.nil?

    reference.strip!
    return if reference.empty?

    return reference
  end

  def assemble_output_statements_and_accumulate_assets()
    @local_resource_paths = []
    @asset_names_with_associated_input_statements = {}

    @text_assembler.input_statements.each do
      |statement|

      if statement.is_asset?
        add_asset_to_output_statements(statement)
      else
        @text_assembler.add_output statement
      end
    end

    return
  end

  def add_asset_to_output_statements(asset_statement)
    if Fig::URL.is_url? asset_statement.location
      add_output_asset_statement_based_upon_input_statement(
        asset_statement, asset_statement
      )
    elsif asset_statement.is_a? Fig::Statement::Archive
      if asset_statement.requires_globbing?
        expand_globs_from( [asset_statement.location] ).each do
          |file|

          add_output_asset_statement_based_upon_input_statement(
            Fig::Statement::Archive.new(
              nil,
              %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
              file,
              false # No globbing
            ),
            asset_statement
          )
        end
      else
        add_output_asset_statement_based_upon_input_statement(
          asset_statement, asset_statement
        )
      end
    elsif asset_statement.requires_globbing?
      @local_resource_paths.concat expand_globs_from(
        [asset_statement.location]
      )
    else
      @local_resource_paths << asset_statement.location
    end

    return
  end

  def add_output_asset_statement_based_upon_input_statement(
    output_statement, input_statement
  )
    @text_assembler.add_output output_statement

    asset_name = output_statement.asset_name

    input_statements =
      @asset_names_with_associated_input_statements[asset_name]
    if input_statements.nil?
      input_statements = []

      @asset_names_with_associated_input_statements[asset_name] =
        input_statements
    end

    input_statements << input_statement

    return
  end

  def validate_asset_names()
    found_problem = false

    @asset_names_with_associated_input_statements.keys.sort.each do
      |asset_name|

      statements = @asset_names_with_associated_input_statements[asset_name]

      if asset_name == Fig::Repository::RESOURCES_FILE
        Fig::Logging.fatal \
          %Q<You cannot have an asset with the name "#{Fig::Repository::RESOURCES_FILE}"#{collective_position_string(statements)} due to Fig implementation details.>
        found_problem = true
      end

      archive_statements =
        statements.select { |s| s.is_a? Fig::Statement::Archive }
      if (
            not archive_statements.empty? \
        and not (
              asset_name =~ /\.tar\.gz$/    \
          or  asset_name =~ /\.tgz$/        \
          or  asset_name =~ /\.tar\.bz2$/   \
          or  asset_name =~ /\.zip$/
        )
      )
        Fig::Logging.fatal \
          %Q<Unknown archive type "#{asset_name}"#{collective_position_string(archive_statements)}.>
        found_problem = true
      end

      if statements.size > 1
        Fig::Logging.fatal \
          %Q<Found multiple assets with the name "#{asset_name}"#{collective_position_string(statements)}. If these were allowed, assets would overwrite each other.>
        found_problem = true
      end
    end

    if found_problem
        raise Fig::RepositoryError.new
    end
  end

  def collective_position_string(statements)
    return (
      statements.map {
        |statement|

        position_string = statement.position_string

        position_string.empty? ? '<unknown>' : position_string.strip
      }
    ).join(', ')
  end

  def create_resource_archive()
    if @local_resource_paths.size > 0
      check_asset_paths(@local_resource_paths)

      file = File.join publish_temp_dir, Fig::Repository::RESOURCES_FILE
      @operating_system.create_archive(file, @local_resource_paths)
      Fig::AtExit.add { FileUtils.rm_f(file) }

      @text_assembler.add_output(
        Fig::Statement::SyntheticRawText.new(nil, nil, "\n"),
        Fig::Statement::Archive.new(
          nil,
          %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
          file,
          false # No globbing
        )
      )
    end

    return
  end

  def publish_package_contents()
    @text_assembler.output_statements.each do
      |statement|

      if statement.is_asset?
        publish_asset(statement)
      end
    end

    return
  end

  def publish_asset(asset_statement)
    asset_name = asset_statement.asset_name()

    if Fig::URL.is_url? asset_statement.location
      asset_local = File.join(publish_temp_dir(), asset_name)

      begin
        @operating_system.download(asset_statement.location, asset_local, false)
      rescue Fig::FileNotFoundError
        Fig::Logging.fatal "Could not download #{asset_statement.location}."
        raise Fig::RepositoryError.new
      end
    else
      asset_local = asset_statement.location
      check_asset_path(asset_local)
    end

    if not @local_only
      asset_remote = Fig::URL.append_path_components(
        @remote_directory_for_package, [asset_name],
      )

      @operating_system.upload(asset_local, asset_remote)
    end

    @operating_system.copy(
      asset_local, @local_directory_for_package + '/' + asset_name
    )
    if asset_statement.is_a?(Fig::Statement::Archive)
      @operating_system.unpack_archive(
        @runtime_for_package, File.absolute_path(asset_local)
      )
    else
      @operating_system.copy(
        asset_local, @runtime_for_package + '/' + asset_name
      )
    end

    return
  end

  def add_unparsed_text()
    if @source_package && @source_package.unparsed_text
      @text_assembler.add_footer ''
      @text_assembler.add_footer '# Original, unparsed package text:'
      @text_assembler.add_footer '#'
      @text_assembler.add_footer(
        @source_package.unparsed_text.gsub(/^(?=[^\n]+$)/, '# ').gsub(/^$/, '#')
      )
    end

    return
  end

  def notify_listeners()
    publish_information = {}
    publish_information[:descriptor]          = @descriptor
    publish_information[:time]                = @publish_time
    publish_information[:login]               = @publish_login
    publish_information[:host]                = @publish_host

    # Ensure that we've really got booleans and not merely true or false
    # values.
    publish_information[:was_forced]          = @was_forced ? true : false
    publish_information[:local_only]          = @local_only ? true : false

    publish_information[:local_destination]   = @local_directory_for_package
    publish_information[:remote_destination]  = @remote_directory_for_package

    @publish_listeners.each do
      |listener|

      listener.published(publish_information)
    end

    return
  end

  def publish_temp_dir()
    File.join(@base_temp_dir, 'publish')
  end

  def check_asset_path(asset_path)
    if not File.exist?(asset_path)
      Fig::Logging.fatal "Could not find file #{asset_path}."
      raise Fig::RepositoryError.new
    end

    return
  end

  def check_asset_paths(asset_paths)
    non_existing_paths =
      asset_paths.select {|path| ! File.exist?(path) && ! File.symlink?(path) }

    if not non_existing_paths.empty?
      if non_existing_paths.size > 1
        Fig::Logging.fatal "Could not find files: #{ non_existing_paths.join(', ') }"
      else
        Fig::Logging.fatal "Could not find file #{non_existing_paths[0]}."
      end

      raise Fig::RepositoryError.new
    end

    return
  end

  def check_published_environment_variables(published_package)
    published_package.walk_statements do
      |statement|

      if statement.is_environment_variable?
        tokenized_value = statement.tokenized_value
        expansion_happened = false
        expanded_value = tokenized_value.to_expanded_string {
          expansion_happened = true; published_package.runtime_directory
        }

        if expansion_happened && ! File.exist?(expanded_value) && ! File.symlink?(expanded_value)
          Fig::Logging.warn(
            %Q<The #{statement.name} variable points to a path that does not exist (#{expanded_value}); retrieve statements that are active when this package is included may fail.>
          )
        end
      end
    end

    return
  end

  # 'paths' is an Array of fileglob patterns: ['tmp/foo/file1',
  # 'tmp/foo/*.jar']
  def expand_globs_from(paths)
    expanded_files = []

    paths.each do
      |path|

      globbed_files = Dir.glob(path)
      if globbed_files.empty?
        expanded_files << path
      else
        expanded_files.concat(globbed_files)
      end
    end

    return expanded_files
  end
end
