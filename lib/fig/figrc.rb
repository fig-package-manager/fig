# coding: utf-8

require 'json'

require 'fig/application_configuration'
require 'fig/config_file_error'
require 'fig/file_not_found_error'
require 'fig/operating_system'
require 'fig/repository'

module Fig; end

# Parse multiple figrc files and assemble them into a single
# ApplicationConfiguration object.
class Fig::FigRC
  REPOSITORY_CONFIGURATION =
      "#{Fig::Repository::METADATA_SUBDIRECTORY}/figrc"
  def self.find(
    override_path,
    download_repository_url,
    upload_repository_url,
    operating_system,
    fig_home,
    disable_figrc = false,
    disable_remote_figrc = false
  )
    configuration = Fig::ApplicationConfiguration.new()

    handle_override_configuration(configuration, override_path)
    handle_figrc(configuration) if not disable_figrc
    
    # Check for legacy environment variable usage
    download_url = derive_repository_url(download_repository_url, 'DOWNLOAD', configuration)
    upload_url = derive_repository_url(upload_repository_url, 'UPLOAD', configuration)
    remote_url = ENV['FIG_REMOTE_URL']
    
    has_download = !download_url.nil? && !download_url.strip.empty?
    has_upload = !upload_url.nil? && !upload_url.strip.empty?
    has_remote = !remote_url.nil? && !remote_url.strip.empty?
    
    # Error case: FIG_REMOTE_URL exists but one or both new URLs missing
    if has_remote && (!has_download || !has_upload)
      raise Fig::UserInputError.new(
        'FIG_REMOTE_URL is set but FIG_DOWNLOAD_URL and/or FIG_UPLOAD_URL are missing. ' +
        'Please set both FIG_DOWNLOAD_URL and FIG_UPLOAD_URL instead of FIG_REMOTE_URL.'
      )
    end

    # Warning case: All three variables exist
    if has_remote && has_download && has_upload
      $stderr.puts "WARNING: FIG_REMOTE_URL is set but will be ignored. Using FIG_DOWNLOAD_URL and FIG_UPLOAD_URL instead."
    end
    
    # Set the new URL attributes
    configuration.remote_download_url = download_url
    configuration.remote_upload_url = upload_url
    
    # For backward compatibility with code expecting whitelisted URLs
    url_for_whitelist = has_download ? download_url : nil
    configuration.base_whitelisted_url = url_for_whitelist
    
    # Handle repository configuration if enabled
    if !disable_remote_figrc && has_download
      handle_repository_configuration(
        configuration, download_url, operating_system, fig_home
      )
    end
    
    return configuration
  end

  private

  def self.handle_override_configuration(configuration, override_path)
    begin
      if not override_path.nil?
        configuration_text = File::open(override_path).read
        if configuration_text.length > 0
          configuration.push_dataset JSON.parse(configuration_text)
        end
      end
    rescue JSON::ParserError => exception
      translate_parse_error(exception, override_path)
    end

    return
  end

  def self.handle_figrc(configuration)
    user_figrc_path = File.expand_path('~/.figrc')
    return if not File.exist? user_figrc_path

    begin
      configuration_text = File::open(user_figrc_path).read
      configuration.push_dataset JSON.parse(configuration_text)
    rescue JSON::ParserError => exception
      translate_parse_error(exception, user_figrc_path)
    end

    return
  end

  def self.derive_repository_url(specified_repository_url, which, configuration)
    if specified_repository_url.nil?
      return configuration["default FIG_#{which}_URL"]
    end

    if specified_repository_url.empty? || specified_repository_url =~ /\A\s*\z/
      return nil
    end

    return specified_repository_url
  end

  def self.handle_repository_configuration(
    configuration, repository_url, operating_system, fig_home
  )
    return if repository_url.nil?

    figrc_url = "#{repository_url}/#{REPOSITORY_CONFIGURATION}"
    repo_figrc_path =
      File.expand_path(File.join(fig_home, REPOSITORY_CONFIGURATION))

    repo_config_exists = nil
    begin
      operating_system.download figrc_url, repo_figrc_path, :prompt_for_login
      repo_config_exists = true
    rescue Fig::FileNotFoundError
      repo_config_exists = false
    end

    return if not repo_config_exists

    begin
      configuration_text = File.open(repo_figrc_path).read
      if configuration_text.empty?
        raise Fig::ConfigFileError.new(
          "Local copy (#{repo_figrc_path}) of #{figrc_url} is empty!",
          figrc_url,
        )
      end

      configuration.push_dataset JSON.parse(configuration_text)
    rescue JSON::ParserError => exception
      translate_parse_error(exception, repo_figrc_path)
    end

    return
  end

  def self.translate_parse_error(json_parse_error, config_file_path)
    message = json_parse_error.message
    message.chomp!

    # JSON::ParserError tends to include final newline inside of single
    # quotes, which makes error messages ugly.
    message.sub!(/ \n+ ' \z /xm, %q<'>)

    # Also, there's a useless source code line number in the message.
    message.sub!(/ \A \d+ : \s+ /xm, %q<>)

    raise Fig::ConfigFileError.new(
      "Parse issue with #{config_file_path}: #{message}",
      config_file_path
    )
  end
end
