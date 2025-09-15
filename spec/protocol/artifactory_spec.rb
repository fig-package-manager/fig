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
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
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
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
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
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
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
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
          .and_return(response)

        result = artifactory.send(:get_all_artifactory_entries, base_url, mock_client)
        expect(result).to eq([])
      end
    end
  end

  describe '#download_list' do
    let(:uri) { URI('https://artifacts.example.com/artifactory/repo-name/') }
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
          .with(URI('https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
          .and_return(packages_response)

        expect(mock_client).to receive(:get)
          .with(URI('https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/package-a/?recordNum=3000'))
          .and_return(package_a_versions)

        expect(mock_client).to receive(:get)
          .with(URI('https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/package-b/?recordNum=3000'))
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
          .with(URI('https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
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
          .with(URI('https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
          .and_return(packages_response)

        expect(mock_client).to receive(:get)
          .with(URI('https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/good-package/?recordNum=3000'))
          .and_return(good_versions)

        expect(mock_client).to receive(:get)
          .with(URI('https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/bad-package/?recordNum=3000'))
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
          .with(URI('https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
          .and_return(packages_response)

        expect(mock_client).to receive(:get)
          .with(URI('https://artifacts.example.com/ui/api/v1/ui/v2/nativeBrowser/repo-name/valid-package/?recordNum=3000'))
          .and_return(valid_versions)

        result = artifactory.download_list(uri)
        expect(result).to eq(['valid-package/1.0.0'])
      end
    end
  end

  describe '#download' do
    let(:uri) { URI('https://artifacts.example.com/artifactory/repo-name/package/version/file.tar.gz') }
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
        allow(artifactory).to receive(:download_via_http_get).with(uri.to_s, mock_file)

        expect(Fig::Logging).to receive(:debug).with("Equivalent curl: curl -u testuser:*** -o '#{path}' '#{uri}'")

        result = artifactory.download(uri, path, prompt_for_login)
        expect(result).to be true
      end
    end

    context 'without authentication' do
      it 'downloads file and logs curl equivalent without auth' do
        allow(artifactory).to receive(:get_authentication_for).with(uri.host, prompt_for_login).and_return(nil)
        allow(artifactory).to receive(:download_via_http_get).with(uri.to_s, mock_file)

        expect(Fig::Logging).to receive(:debug).with("Equivalent curl: curl -o '#{path}' '#{uri}'")

        result = artifactory.download(uri, path, prompt_for_login)
        expect(result).to be true
      end
    end

    context 'when download_via_http_get raises SystemCallError' do
      it 'wraps error in FileNotFoundError' do
        allow(artifactory).to receive(:get_authentication_for).and_return(nil)
        system_error = SystemCallError.new('Connection failed')
        allow(artifactory).to receive(:download_via_http_get).and_raise(system_error)

        expect(Fig::Logging).to receive(:debug).with("Equivalent curl: curl -o '#{path}' '#{uri}'")
        expect(Fig::Logging).to receive(:debug).with('unknown error - Connection failed')
        expect { artifactory.download(uri, path, prompt_for_login) }.to raise_error(Fig::FileNotFoundError, 'unknown error - Connection failed')
      end
    end

    context 'when download_via_http_get raises SocketError' do
      it 'wraps error in FileNotFoundError' do
        allow(artifactory).to receive(:get_authentication_for).and_return(nil)
        socket_error = SocketError.new('Host not found')
        allow(artifactory).to receive(:download_via_http_get).and_raise(socket_error)

        expect(Fig::Logging).to receive(:debug).with("Equivalent curl: curl -o '#{path}' '#{uri}'")
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
