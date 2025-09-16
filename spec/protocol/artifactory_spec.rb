# coding: utf-8

require 'spec_helper'
require 'fig/protocol/artifactory'

describe Fig::Protocol::Artifactory do
  let(:artifactory) { Fig::Protocol::Artifactory.new }
  let(:base_url) { URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/') }

  describe '#get_all_artifactory_entries' do
    let(:mock_client) { double('Artifactory::Client') }
    let(:base_url) { URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/') }

    before do
      # Stub netrc authentication
      allow(artifactory).to receive(:get_authentication_for).and_return(nil)
    end

    context 'when all entries fit in single page' do
      it 'returns entries without pagination' do
        response = {
          'data' => [
            { 'name' => 'package1', 'folder' => true },
            { 'name' => 'package2', 'folder' => true }
          ],
          'continueState' => -1
        }
        
        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(response)

        result = artifactory.send(:get_all_artifactory_entries, base_url, mock_client)
        expect(result).to eq(response['data'])
      end
    end

    context 'when entries require pagination' do
      it 'follows pagination until continueState is -1' do
        first_response = {
          'data' => [
            { 'name' => 'package1', 'folder' => true },
            { 'name' => 'package2', 'folder' => true }
          ],
          'continueState' => 'cursor123'
        }
        
        final_response = {
          'data' => [
            { 'name' => 'package1', 'folder' => true },
            { 'name' => 'package2', 'folder' => true },
            { 'name' => 'package3', 'folder' => true }
          ],
          'continueState' => -1
        }

        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(first_response)
          
        expect(mock_client).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=cursor123'))
          .and_return(final_response)

        result = artifactory.send(:get_all_artifactory_entries, base_url, mock_client)
        expect(result).to eq(final_response['data'])
      end
    end

    context 'when continueState is nil' do
      it 'returns entries and stops pagination' do
        response = {
          'data' => [{ 'name' => 'package1', 'folder' => true }],
          'continueState' => nil
        }
        
        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(response)

        result = artifactory.send(:get_all_artifactory_entries, base_url, mock_client)
        expect(result).to eq(response['data'])
      end
    end

    context 'when FIG_ARTIFACTORY_PAGESIZE is set' do
      it 'uses custom page size' do
        allow(ENV).to receive(:[]).with('FIG_ARTIFACTORY_PAGESIZE').and_return('5000')
        
        response = {
          'data' => [{ 'name' => 'package1', 'folder' => true }],
          'continueState' => -1
        }
        
        expect(mock_client).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=5000'))
          .and_return(response)

        result = artifactory.send(:get_all_artifactory_entries, base_url, mock_client)
        expect(result).to eq(response['data'])
      end
    end

    context 'when response has no data field' do
      it 'returns empty array' do
        response = { 'continueState' => -1 }
        
        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(response)

        result = artifactory.send(:get_all_artifactory_entries, base_url, mock_client)
        expect(result).to eq([])
      end
    end
  end

  describe '#download_list' do
    let(:uri) { URI('art://artifacts.example.com/artifactory/repo-name/') }
    let(:artifactory) { Fig::Protocol::Artifactory.new }
    let(:mock_client) { double('Artifactory::Client') }

    before do
      allow(::Artifactory::Client).to receive(:new).and_return(mock_client)
      # Stub netrc authentication
      allow(artifactory).to receive(:get_authentication_for).and_return(nil)
    end

    context 'when repository has packages and versions' do
      it 'returns sorted package/version strings' do
        # Mock package listing
        packages_response = {
          'data' => [
            { 'name' => 'package-a', 'folder' => true },
            { 'name' => 'package-b', 'folder' => true },
            { 'name' => 'readme.txt', 'folder' => false }  # Should be ignored
          ],
          'continueState' => -1
        }

        # Mock version listings for each package
        package_a_versions = {
          'data' => [
            { 'name' => '1.0.0', 'folder' => true },
            { 'name' => '2.0.0', 'folder' => true },
            { 'name' => 'metadata.xml', 'folder' => false }  # Should be ignored
          ],
          'continueState' => -1
        }

        package_b_versions = {
          'data' => [
            { 'name' => '0.5.0', 'folder' => true }
          ],
          'continueState' => -1
        }

        # Expect calls in order
        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(packages_response)

        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/package-a/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(package_a_versions)

        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/package-b/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(package_b_versions)

        result = artifactory.download_list(uri)
        expect(result).to eq([
          'package-a/1.0.0',
          'package-a/2.0.0', 
          'package-b/0.5.0'
        ])
      end
    end

    context 'when repository is empty' do
      it 'returns empty array' do
        empty_response = {
          'data' => [],
          'continueState' => -1
        }

        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(empty_response)

        result = artifactory.download_list(uri)
        expect(result).to eq([])
      end
    end

    context 'when API calls fail' do
      it 'handles errors gracefully and continues processing' do
        packages_response = {
          'data' => [
            { 'name' => 'good-package', 'folder' => true },
            { 'name' => 'bad-package', 'folder' => true }
          ],
          'continueState' => -1
        }

        good_versions = {
          'data' => [{ 'name' => '1.0.0', 'folder' => true }],
          'continueState' => -1
        }

        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(packages_response)

        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/good-package/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(good_versions)

        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/bad-package/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_raise(StandardError.new('API error'))

        # Should continue processing despite error
        result = artifactory.download_list(uri)
        expect(result).to eq(['good-package/1.0.0'])
      end
    end

    context 'with invalid package/version names' do
      it 'filters out names that do not match COMPONENT_PATTERN' do
        packages_response = {
          'data' => [
            { 'name' => 'valid-package', 'folder' => true },
            { 'name' => 'invalid package with spaces', 'folder' => true },
            { 'name' => 'invalid@symbols', 'folder' => true }
          ],
          'continueState' => -1
        }

        valid_versions = {
          'data' => [
            { 'name' => '1.0.0', 'folder' => true },
            { 'name' => 'invalid version', 'folder' => true }
          ],
          'continueState' => -1
        }

        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(packages_response)

        expect(mock_client).to receive(:get)
          .with(URI("https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/valid-package/?recordNum=#{Fig::Protocol::Artifactory::INITIAL_LIST_FETCH_SIZE}"))
          .and_return(valid_versions)

        result = artifactory.download_list(uri)
        expect(result).to eq(['valid-package/1.0.0'])
      end
    end
  end

  describe '#download' do
    let(:uri) { URI('artifactory://artifacts.example.com/artifactory/repo-name/package/version/file.tar.gz') }
    let(:https_uri) { URI(uri.to_s.sub(/\Aartifactory:/, 'https:')) }
    let(:path) { '/tmp/test_file.tar.gz' }
    let(:prompt_for_login) { false }
    let(:mock_file) { double('File') }
    let(:mock_auth) { double('Authentication', username: 'testuser', password: 'testpass') }

    before do
      allow(::File).to receive(:open).with(path, 'wb').and_yield(mock_file)
      allow(mock_file).to receive(:binmode)
    end

    context 'with authentication' do
      it 'downloads file and logs curl equivalent with auth' do
        allow(artifactory).to receive(:get_authentication_for).with(uri.host, prompt_for_login).and_return(mock_auth)
        allow(artifactory).to receive(:download_via_http_get).with(https_uri.to_s, mock_file)

        expect(Fig::Logging).to receive(:debug).with("Equivalent curl: curl -u testuser:*** -o '#{path}' '#{https_uri}'")

        result = artifactory.download(uri, path, prompt_for_login)
        expect(result).to be true
      end
    end

    context 'without authentication' do
      it 'downloads file and logs curl equivalent without auth' do
        allow(artifactory).to receive(:get_authentication_for).with(uri.host, prompt_for_login).and_return(nil)
        allow(artifactory).to receive(:download_via_http_get).with(https_uri.to_s, mock_file)

        expect(Fig::Logging).to receive(:debug).with("Equivalent curl: curl -o '#{path}' '#{https_uri}'")

        result = artifactory.download(uri, path, prompt_for_login)
        expect(result).to be true
      end
    end

    context 'when download_via_http_get raises SystemCallError' do
      it 'wraps error in FileNotFoundError' do
        allow(artifactory).to receive(:get_authentication_for).and_return(nil)
        system_error = SystemCallError.new('Connection failed')
        allow(artifactory).to receive(:download_via_http_get).and_raise(system_error)

        expect(Fig::Logging).to receive(:debug).with("Equivalent curl: curl -o '#{path}' '#{https_uri}'")
        expect(Fig::Logging).to receive(:debug).with('unknown error - Connection failed')
        expect { artifactory.download(uri, path, prompt_for_login) }.to raise_error(Fig::FileNotFoundError, 'unknown error - Connection failed')
      end
    end

    context 'when download_via_http_get raises SocketError' do
      it 'wraps error in FileNotFoundError' do
        allow(artifactory).to receive(:get_authentication_for).and_return(nil)
        socket_error = SocketError.new('Host not found')
        allow(artifactory).to receive(:download_via_http_get).and_raise(socket_error)

        expect(Fig::Logging).to receive(:debug).with("Equivalent curl: curl -o '#{path}' '#{https_uri}'")
        expect(Fig::Logging).to receive(:debug).with('Host not found')
        expect { artifactory.download(uri, path, prompt_for_login) }.to raise_error(Fig::FileNotFoundError, 'Host not found')
      end
    end

    it 'opens file in binary write mode' do
      allow(artifactory).to receive(:get_authentication_for).and_return(nil)
      allow(artifactory).to receive(:download_via_http_get)

      expect(::File).to receive(:open).with(path, 'wb')
      expect(mock_file).to receive(:binmode)

      artifactory.download(uri, path, prompt_for_login)
    end
  end

  describe '#httpify_uri' do
    let(:artifactory) { Fig::Protocol::Artifactory.new }

    it 'converts art:// scheme to https://' do
      art_uri = URI('art://artifacts.example.com/artifactory/repo-name/')
      result = artifactory.send(:httpify_uri, art_uri)
      
      expect(result.scheme).to eq('https')
      expect(result.host).to eq('artifacts.example.com')
      expect(result.path).to eq('/artifactory/repo-name/')
      expect(result).to be_a(URI::HTTPS)
    end

    it 'converts artifactory:// scheme to https://' do
      art_uri = URI('artifactory://artifacts.example.com/artifactory/repo-name/package/version/file.tar.gz')
      result = artifactory.send(:httpify_uri, art_uri)
      
      expect(result.scheme).to eq('https')
      expect(result.host).to eq('artifacts.example.com')
      expect(result.path).to eq('/artifactory/repo-name/package/version/file.tar.gz')
      expect(result).to be_a(URI::HTTPS)
    end

    it 'preserves port and query parameters' do
      art_uri = URI('art://artifacts.example.com:8080/artifactory/repo-name/?param=value')
      result = artifactory.send(:httpify_uri, art_uri)
      
      expect(result.scheme).to eq('https')
      expect(result.host).to eq('artifacts.example.com')
      expect(result.port).to eq(8080)
      expect(result.path).to eq('/artifactory/repo-name/')
      expect(result.query).to eq('param=value')
      expect(result).to be_a(URI::HTTPS)
    end

    it 'handles URIs with userinfo' do
      art_uri = URI('artifactory://user:pass@artifacts.example.com/artifactory/repo-name/')
      result = artifactory.send(:httpify_uri, art_uri)
      
      expect(result.scheme).to eq('https')
      expect(result.userinfo).to eq('user:pass')
      expect(result.host).to eq('artifacts.example.com')
      expect(result.path).to eq('/artifactory/repo-name/')
      expect(result).to be_a(URI::HTTPS)
    end
  end

  describe '#parse_uri' do
    let(:artifactory) { Fig::Protocol::Artifactory.new }

    context 'with basic artifactory URI' do
      it 'parses repository-level URI correctly' do
        art_uri = URI('art://artifacts.example.com/artifactory/repo-name/')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:repo_key]).to eq('repo-name')
        expect(result[:base_endpoint]).to eq('https://artifacts.example.com/artifactory')
        expect(result[:target_path]).to eq('')
      end

      it 'parses URI with file path correctly' do
        art_uri = URI('artifactory://artifacts.example.com/artifactory/repo-name/package/version/file.tar.gz')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:repo_key]).to eq('repo-name')
        expect(result[:base_endpoint]).to eq('https://artifacts.example.com/artifactory')
        expect(result[:target_path]).to eq('package/version/file.tar.gz')
      end

      it 'parses URI with nested directory path correctly' do
        art_uri = URI('art://artifacts.example.com/artifactory/my-repo/com/example/package/1.0.0/package-1.0.0.jar')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:repo_key]).to eq('my-repo')
        expect(result[:base_endpoint]).to eq('https://artifacts.example.com/artifactory')
        expect(result[:target_path]).to eq('com/example/package/1.0.0/package-1.0.0.jar')
      end
    end

    context 'with custom port' do
      it 'includes port in base_endpoint when non-standard' do
        art_uri = URI('artifactory://artifacts.example.com:8080/artifactory/repo-name/file.txt')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:repo_key]).to eq('repo-name')
        expect(result[:base_endpoint]).to eq('https://artifacts.example.com:8080/artifactory')
        expect(result[:target_path]).to eq('file.txt')
      end

      it 'excludes default HTTPS port from base_endpoint' do
        art_uri = URI('art://artifacts.example.com:443/artifactory/repo-name/file.txt')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:repo_key]).to eq('repo-name')
        expect(result[:base_endpoint]).to eq('https://artifacts.example.com/artifactory')
        expect(result[:target_path]).to eq('file.txt')
      end
    end

    context 'with artifactory in different path positions' do
      it 'handles artifactory in root path' do
        art_uri = URI('art://artifacts.example.com/artifactory/repo-name/file.txt')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:repo_key]).to eq('repo-name')
        expect(result[:base_endpoint]).to eq('https://artifacts.example.com/artifactory')
        expect(result[:target_path]).to eq('file.txt')
      end

      it 'handles artifactory in nested path' do
        art_uri = URI('artifactory://artifacts.example.com/some/path/artifactory/repo-name/file.txt')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:repo_key]).to eq('repo-name')
        expect(result[:base_endpoint]).to eq('https://artifacts.example.com/some/path/artifactory')
        expect(result[:target_path]).to eq('file.txt')
      end
    end

    context 'with trailing slashes' do
      it 'handles URI with trailing slash' do
        art_uri = URI('art://artifacts.example.com/artifactory/repo-name/')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:repo_key]).to eq('repo-name')
        expect(result[:base_endpoint]).to eq('https://artifacts.example.com/artifactory')
        expect(result[:target_path]).to eq('')
      end

      it 'handles URI without trailing slash' do
        art_uri = URI('artifactory://artifacts.example.com/artifactory/repo-name')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:repo_key]).to eq('repo-name')
        expect(result[:base_endpoint]).to eq('https://artifacts.example.com/artifactory')
        expect(result[:target_path]).to eq('')
      end
    end

    context 'error cases' do
      it 'raises ArgumentError when artifactory is not in path' do
        art_uri = URI('art://artifacts.example.com/some/other/path/repo-name/')
        
        expect {
          artifactory.send(:parse_uri, art_uri)
        }.to raise_error(ArgumentError, /URI must contain 'artifactory' in path/)
      end

      it 'raises ArgumentError when no repository key is found' do
        art_uri = URI('artifactory://artifacts.example.com/artifactory/')
        
        expect {
          artifactory.send(:parse_uri, art_uri)
        }.to raise_error(ArgumentError, /No repository key found in URI/)
      end

      it 'raises ArgumentError when artifactory is at end of path' do
        art_uri = URI('art://artifacts.example.com/some/path/artifactory')
        
        expect {
          artifactory.send(:parse_uri, art_uri)
        }.to raise_error(ArgumentError, /No repository key found in URI/)
      end
    end

    context 'edge cases' do
      it 'handles empty target path correctly' do
        art_uri = URI('artifactory://artifacts.example.com/artifactory/repo-name')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:target_path]).to eq('')
      end

      it 'handles single character repo key' do
        art_uri = URI('art://artifacts.example.com/artifactory/r/file.txt')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:repo_key]).to eq('r')
        expect(result[:target_path]).to eq('file.txt')
      end

      it 'handles repo key with special characters' do
        art_uri = URI('artifactory://artifacts.example.com/artifactory/repo-name-with-dashes_and_underscores/file.txt')
        result = artifactory.send(:parse_uri, art_uri)
        
        expect(result[:repo_key]).to eq('repo-name-with-dashes_and_underscores')
        expect(result[:target_path]).to eq('file.txt')
      end
    end
  end

  describe '#upload' do
    let(:local_file) { '/tmp/test.txt' }
    let(:uri) { URI('https://artifacts.example.com/artifactory/repo-name/path/to/file.txt') }
    let(:mock_client) { double('Artifactory::Client') }
    let(:mock_artifact) { double('Artifactory::Resource::Artifact') }
    let(:mock_authentication) { double('authentication', username: 'testuser', password: 'testpass') }

    before do
      allow(artifactory).to receive(:get_authentication_for).and_return(mock_authentication)
      allow(::Artifactory::Client).to receive(:new).and_return(mock_client)
      allow(::Artifactory::Resource::Artifact).to receive(:new).and_return(mock_artifact)
      allow(::File).to receive(:stat).and_return(double('stat', size: 1024, mtime: Time.now))
      allow(Digest::SHA1).to receive(:file).and_return(double(hexdigest: 'sha1hash'))
      allow(Digest::MD5).to receive(:file).and_return(double(hexdigest: 'md5hash'))
    end

    it 'parses URI correctly and uploads file' do
      expect(::Artifactory::Client).to receive(:new).with({
        endpoint: 'https://artifacts.example.com/artifactory',
        username: 'testuser',
        password: 'testpass'
      })
      
      expect(mock_artifact).to receive(:upload).with(
        'repo-name',
        'path/to/file.txt',
        hash_including('fig.original_path' => local_file),
        client: mock_client
      )

      artifactory.upload(local_file, uri)
    end

    it 'logs equivalent curl command' do
      allow(mock_artifact).to receive(:upload)
      
      expect(Fig::Logging).to receive(:debug).with(
        "Equivalent curl: curl -u testuser:*** -T '#{local_file}' '#{uri}'"
      ).ordered
      expect(Fig::Logging).to receive(:debug).with(
        /Upload metadata:/
      ).ordered

      artifactory.upload(local_file, uri)
    end

    it 'raises error for invalid URI without artifactory in path' do
      invalid_uri = URI('https://example.com/repo-name/file.txt')
      
      expect {
        artifactory.upload(local_file, invalid_uri)
      }.to raise_error(ArgumentError, /URI must contain 'artifactory' in path/)
    end

    it 'collects metadata with fig. prefix' do
      metadata_hash = nil
      allow(mock_artifact).to receive(:upload) do |repo, path, metadata, options|
        metadata_hash = metadata
      end

      artifactory.upload(local_file, uri)

      expect(metadata_hash).to include(
        'fig.original_path' => local_file,
        'fig.target_path' => 'path/to/file.txt',
        'fig.tool' => 'fig-artifactory-protocol'
      )
      expect(metadata_hash.keys).to all(start_with('fig.'))
    end
  end
end
