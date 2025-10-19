# coding: utf-8

require 'net/http'
require 'uri'
require 'etc'
require 'thread'
require 'socket'
require 'digest'
require 'time'

require 'artifactory'

require 'fig/logging'
require 'fig/network_error'
require 'fig/package_descriptor'
require 'fig/protocol'
require 'fig/protocol/netrc_enabled'


module Fig; end
module Fig::Protocol; end


# file transfers/storage using https as the transport and artifactory as the backing store
class Fig::Protocol::Artifactory
  include Fig::Protocol
  include Fig::Protocol::NetRCEnabled

  # Artifactory browser API endpoint (undocumented API)
  BROWSER_API_PATH = 'ui/api/v1/ui/v2/nativeBrowser/'

  # Default number of list entries to fetch on initial iteration
  INITIAL_LIST_FETCH_SIZE = 20000

  def initialize(login)
    @login = login
    initialize_netrc
  end

  # like ftp's ftp_login
  def artifactory_auth(client_config, host, prompt_for_login)
    if @login
      auth = get_authentication_for(host, prompt_for_login)
      if auth
        client_config[:username] = auth.username
        client_config[:password] = auth.password
      end
    end
  end

  # must return a list of strings in the form <package_name>/<version>
  def download_list(uri)
    Fig::Logging.info("Downloading list of packages at #{uri}")
    package_versions = []

    begin
      # Parse URI to extract base endpoint and repository key
      # Expected format: https://artifacts.example.com/artifactory/repo-name/
      parse_uri(uri) => { repo_key:, base_endpoint: }
      
      # Create Artifactory client instance
      client_config = { endpoint: base_endpoint }
      artifactory_auth(client_config, uri.host, :prompt_for_login)
      client = ::Artifactory::Client.new(client_config)

      # Use Artifactory browser API to list directories at repo root
      list_url = URI.join(base_endpoint, BROWSER_API_PATH, "#{repo_key}/")
      
      packages = get_all_artifactory_entries(list_url, client)
      
      # Filter to only valid package names upfront
      valid_packages = packages.select do |package_item|
        package_item['folder'] && 
        package_item['name'] =~ Fig::PackageDescriptor::COMPONENT_PATTERN
      end
      
      Fig::Logging.debug("Found #{valid_packages.size} valid packages, fetching versions concurrently...")
      
      # Use concurrent requests to fetch version lists (major performance improvement)
      package_versions = fetch_versions_concurrently(valid_packages, base_endpoint, repo_key, client_config)
      
    rescue => e
      # Follow FTP pattern: log error but don't fail completely
      Fig::Logging.debug("Could not retrieve package list from #{uri}: #{e.message}")
    end

    return package_versions.sort
  end

  def download(art_uri, path, prompt_for_login)
    Fig::Logging.info("Downloading from artifactory: #{art_uri}")

    uri = httpify_uri(art_uri)

    # Log equivalent curl command for debugging
    client_config = { endpoint: art_uri }
    artifactory_auth(client_config, uri.host, prompt_for_login)
    
    if client_config[:username]
      Fig::Logging.debug("Equivalent curl: curl -u #{client_config[:username]}:*** -o '#{path}' '#{uri}'")
    else
      Fig::Logging.debug("Equivalent curl: curl -o '#{path}' '#{uri}'")
    end

    ::File.open(path, 'wb') do |file|
      file.binmode

      begin
        # TODO seems we should use client_config to do http auth if provided?
        download_via_http_get(uri.to_s, file)
      rescue SystemCallError => error
        Fig::Logging.debug error.message
        raise Fig::FileNotFoundError.new error.message, uri
      rescue SocketError => error
        Fig::Logging.debug error.message
        raise Fig::FileNotFoundError.new error.message, uri
      end
    end

    return true
  end

  def upload(local_file, uri)
    Fig::Logging.info("Uploading #{local_file} to artifactory at #{uri}")

    begin
      parse_uri(uri) => { repo_key:, base_endpoint:, target_path: }

      client_config = { endpoint: base_endpoint }
      artifactory_auth(client_config, uri.host, :prompt_for_login)
      
      # Configure Artifactory gem globally - unlike other methods that can use client instances,
      # the artifact.upload() method ignores the client: parameter and only uses global config.
      # This is a limitation of the artifactory gem's upload implementation.
      ::Artifactory.configure{ |c| client_config.each{|k,v| c.public_send("#{k}=",v)} } # thx o4!

      # Log equivalent curl command for debugging
      if client_config[:username]
        Fig::Logging.debug("Equivalent curl: curl -u #{authentication.username}:*** -T '#{local_file}' '#{uri}'")
      else
        Fig::Logging.debug("Equivalent curl: curl -T '#{local_file}' '#{uri}'")
      end

      # Create artifact and upload
      artifact = ::Artifactory::Resource::Artifact.new(local_path: local_file)
      
      # Collect metadata for upload
      metadata = collect_upload_metadata(local_file, target_path, uri)

      # Upload with metadata (no client parameter needed - uses global config)
      artifact.upload(repo_key, target_path, metadata)
      
      Fig::Logging.info("Successfully uploaded #{local_file} to #{uri}")
      
    rescue ArgumentError => e
      # Let ArgumentError bubble up for invalid URIs
      raise e
    rescue => e
      Fig::Logging.debug("Upload failed: #{e.message}")
      raise Fig::NetworkError.new("Failed to upload #{local_file} to #{uri}: #{e.message}")
    end
  end

  # we can know this most of the time with the stat api
  def path_up_to_date?(uri, path, prompt_for_login)
    Fig::Logging.info("Checking if #{path} is up to date at #{uri}")

    begin
      parse_uri(uri) => { repo_key:, base_endpoint:, target_path: }


      # Create Artifactory client instance (same as upload method)
      client_config = { endpoint: base_endpoint }
      artifactory_auth(client_config, uri.host, :prompt_for_login)
      client = ::Artifactory::Client.new(client_config)
      
      # use storage api instead of search - more reliable for virtual repos
      storage_url = "/api/storage/#{repo_key}/#{target_path}"
      
      response = client.get(storage_url)
      
      # compare sizes first
      remote_size = response['size'].to_i
      if remote_size != ::File.size(path)
        # TODO VERBOSE
        return false
      end
      
      # compare modification times
      remote_mtime = Time.parse(response['lastModified'])
      local_mtime = ::File.mtime(path)
      
      if remote_mtime <= local_mtime
        return true
      end

      # TODO VERBOSE
      return false
    rescue => error
      Fig::Logging.debug "Error checking if #{path} is up to date: #{error.message}"
      return nil
    end
  end

  private

  def httpify_uri(art_uri)
    # if we got into the artifactory protocol, we get to assume that the URI
    # is related to artifactory, which also means we can be assured that the
    # only scheme that will work is 'https' rather than the faux scheme used
    # to signal that the URL is artifactory protocol.

    # this is kind of weird b/c `art_uri` will likely be URI::Generic and
    # everything downstream of here is going to want the type for the URL to
    # be URI::HTTPS. So, we hack the scheme for the input to `https` then
    # parse that string to form the https-based URI with the correct type.
    art_uri.scheme = 'https'
    URI(art_uri.to_s)
  end

  def parse_uri(art_uri)
    uri = httpify_uri(art_uri)

    uri_path = uri.path.chomp('/')
    path_parts = uri_path.split('/').reject(&:empty?)
    
    # Find artifactory in the path and split accordingly
    artifactory_index = path_parts.index('artifactory')
    raise ArgumentError, "URI must contain 'artifactory' in path: #{uri}" unless artifactory_index
    
    repo_key = path_parts[artifactory_index + 1]
    raise ArgumentError, "No repository key found in URI: #{uri}" unless repo_key
    
    # Everything after repo_key is the target path within the repository
    target_path = path_parts[(artifactory_index + 2)..-1]&.join('/') || ''
    
    # Base endpoint includes everything up to and including /artifactory
    artifactory_path = path_parts[0..artifactory_index].join('/')
    the_port = uri.port != uri.default_port ? ":#{uri.port}" : ""
    base_endpoint = "#{uri.scheme}://#{uri.host}#{the_port}/#{artifactory_path}"
    
    { repo_key:, base_endpoint:, target_path: }
  end

  # Collect metadata for file upload, using fig. prefix instead of upload. prefix
  def collect_upload_metadata(local_file, target_path, uri)
    file_stat = ::File.stat(local_file)
    
    metadata = {
      # Basic file information
      'fig.original_path' => local_file,
      'fig.target_path' => target_path,
      'fig.file_size' => file_stat.size.to_s,
      'fig.file_mtime' => file_stat.mtime.iso8601,
      
      # Upload context
      'fig.hostname' => Socket.gethostname,
      'fig.login' => ENV['USER'] || ENV['USERNAME'] || 'unknown',
      'fig.timestamp' => Time.now.iso8601,
      'fig.epoch' => Time.now.to_i.to_s,
      
      # Tool information
      'fig.tool' => 'fig-artifactory-protocol',
      'fig.uri' => uri.to_s,
      
      # Checksums for integrity
      'fig.sha1' => Digest::SHA1.file(local_file).hexdigest,
      'fig.md5' => Digest::MD5.file(local_file).hexdigest,
      
      # TODO: Add package/version metadata from URI path or local_file decoration
      # TODO: Support user-injected metadata via environment variables or callbacks
    }
    
    Fig::Logging.debug("Upload metadata: #{metadata.keys.join(', ')}")
    metadata
  end

  # Fetch version lists for packages concurrently for major performance improvement
  # Reduces ~2700 sequential API calls to concurrent batches
  def fetch_versions_concurrently(valid_packages, base_endpoint, repo_key, client_config)
    # Scale thread count based on CPU cores, with reasonable bounds
    # Testing showed ~25 threads optimal for most servers, so use 3x CPU cores as default
    default_threads = [Etc.nprocessors * 3, 50].min  # cap at 50 to avoid overwhelming servers
    max_threads = ENV['FIG_ARTIFACTORY_THREADS']&.to_i || default_threads
    
    Fig::Logging.debug("Using #{max_threads} threads for concurrent version fetching (#{Etc.nprocessors} CPU cores detected)")
    
    package_versions = []
    package_versions_mutex = Mutex.new
    work_queue = Queue.new
    
    # Add all packages to work queue
    valid_packages.each { |pkg| work_queue << pkg }
    
    # Create worker threads
    threads = []
    max_threads.times do
      threads << Thread.new do
        # Each thread gets its own client to avoid connection issues
        thread_client = ::Artifactory::Client.new(client_config)
        
        while !work_queue.empty?
          begin
            package_item = work_queue.pop(true) # non-blocking pop
          rescue ThreadError
            break # queue is empty
          end
          
          package_name = package_item['name']
          
          begin
            package_list_url = URI.join(base_endpoint, BROWSER_API_PATH, "#{repo_key}/", "#{package_name}/")
            versions = get_all_artifactory_entries(package_list_url, thread_client)
            
            local_package_versions = []
            versions.each do |version_item|
              next unless version_item['folder']
              
              version_name = version_item['name']
              next unless version_name =~ Fig::PackageDescriptor::COMPONENT_PATTERN
              
              local_package_versions << "#{package_name}/#{version_name}"
            end
            
            # Thread-safe addition to results
            package_versions_mutex.synchronize do
              package_versions.concat(local_package_versions)
            end
            
          rescue => e
            # Follow FTP pattern: ignore permission errors and continue processing
            Fig::Logging.debug("Could not list versions for package #{package_name}: #{e.message}")
          end
        end
      end
    end
    
    # Wait for all threads to complete
    threads.each(&:join)
    
    package_versions
  end

  # Get all entries from Artifactory browser API with pagination support
  # Returns array of all entries, handling continueState pagination
  def get_all_artifactory_entries(base_url, client)
    record_num = ENV['FIG_ARTIFACTORY_PAGESIZE']&.to_i || INITIAL_LIST_FETCH_SIZE
    
    Fig::Logging.debug(">> getting art initial #{record_num} entries from #{base_url}...")

    loop do
      # Build URL with recordNum parameter
      url = URI(base_url.to_s)
      url.query = "recordNum=#{record_num}"
      
      response = client.get(url)
      entries = response['data'] || []
      
      # Check if there are more entries to fetch
      continue_state = response['continueState']
      Fig::Logging.debug(">> continue_state is #{continue_state}...")
      return entries if continue_state.nil? || continue_state.to_i < 0
      
      # Use continueState as the recordNum for the next request
      record_num = continue_state
    end
  end

  # swiped directly from http.rb; if no changes are required, then consider refactoring
  def download_via_http_get(uri_string, file, redirection_limit = 10)
    if redirection_limit < 1
      Fig::Logging.debug 'Too many HTTP redirects.'
      raise Fig::FileNotFoundError.new 'Too many HTTP redirects.', uri_string
    end

    response = Net::HTTP.get_response(URI(uri_string))

    case response
    when Net::HTTPSuccess then
      file.write(response.body)
    when Net::HTTPRedirection then
      location = response['location']
      Fig::Logging.debug "Redirecting to #{location}."
      download_via_http_get(location, file, redirection_limit - 1)
    else
      Fig::Logging.debug "Download failed: #{response.code} #{response.message}."
      raise Fig::FileNotFoundError.new(
        "Download failed: #{response.code} #{response.message}.", uri_string
      )
    end

    return
  end
  
end
