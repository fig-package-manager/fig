# coding: utf-8

require 'spec_helper'
require 'fig/protocol/artifactory'

describe Fig::Protocol::Artifactory do
  let(:artifactory) { Fig::Protocol::Artifactory.new }
  let(:base_url) { URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/') }

  describe '#get_all_artifactory_entries' do
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
        
        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
          .and_return(response)

        result = artifactory.send(:get_all_artifactory_entries, base_url)
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

        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
          .and_return(first_response)
          
        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=cursor123'))
          .and_return(final_response)

        result = artifactory.send(:get_all_artifactory_entries, base_url)
        expect(result).to eq(final_response['data'])
      end
    end

    context 'when continueState is nil' do
      it 'returns entries and stops pagination' do
        response = {
          'data' => [{ 'name' => 'package1', 'folder' => true }],
          'continueState' => nil
        }
        
        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
          .and_return(response)

        result = artifactory.send(:get_all_artifactory_entries, base_url)
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
        
        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=5000'))
          .and_return(response)

        result = artifactory.send(:get_all_artifactory_entries, base_url)
        expect(result).to eq(response['data'])
      end
    end

    context 'when response has no data field' do
      it 'returns empty array' do
        response = { 'continueState' => -1 }
        
        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
          .and_return(response)

        result = artifactory.send(:get_all_artifactory_entries, base_url)
        expect(result).to eq([])
      end
    end
  end

  describe '#download_list' do
    let(:uri) { URI('https://artifacts.example.com/artifactory/repo-name/') }
    let(:artifactory) { Fig::Protocol::Artifactory.new }

    before do
      allow(::Artifactory).to receive(:configure)
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
        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
          .and_return(packages_response)

        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/package-a/?recordNum=3000'))
          .and_return(package_a_versions)

        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/package-b/?recordNum=3000'))
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

        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
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

        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
          .and_return(packages_response)

        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/good-package/?recordNum=3000'))
          .and_return(good_versions)

        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/bad-package/?recordNum=3000'))
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

        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/?recordNum=3000'))
          .and_return(packages_response)

        expect(::Artifactory).to receive(:get)
          .with(URI('https://artifacts.example.com/artifactory/ui/api/v1/ui/v2/nativeBrowser/repo-name/valid-package/?recordNum=3000'))
          .and_return(valid_versions)

        result = artifactory.download_list(uri)
        expect(result).to eq(['valid-package/1.0.0'])
      end
    end
  end
end
