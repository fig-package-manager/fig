require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fileutils'
require 'tmpdir'

require 'fig/command/package_loader'
require 'fig/operating_system'
require 'fig/repository'

describe "Split repository URL behavior" do
  context 'starting with a clean home and remote repository' do
    before(:each) do
      clean_up_test_environment
      set_up_test_environment
      cleanup_home_and_remote
    end

    def create_test_repos(unified: false)
      # Name separate download and upload directories
      download_dir = File.join(FIG_SPEC_BASE_DIRECTORY, 'download-repo')
      upload_dir = File.join(FIG_SPEC_BASE_DIRECTORY, 'upload-repo')

      # Clean up any existing directories
      FileUtils.rm_rf(download_dir)
      FileUtils.rm_rf(upload_dir)

      # Create the "repositories" based on whether we want unified or not
      FileUtils.mkdir_p(upload_dir)
      FileUtils.mkdir_p(File.join(upload_dir, Fig::Repository::METADATA_SUBDIRECTORY))

      if unified
        FileUtils.ln_s(upload_dir, download_dir)
      else
        FileUtils.mkdir_p(download_dir)
        FileUtils.mkdir_p(File.join(download_dir, Fig::Repository::METADATA_SUBDIRECTORY))
      end

      return download_dir, upload_dir
    end

    it "(distinct repos) publishes to upload URL and downloads from download URL" do
      # Create separate repos
      download_dir, upload_dir = create_test_repos
      download_url = "file://#{download_dir}"
      upload_url = "file://#{upload_dir}"

      # Set up environment for this test
      ENV['FIG_DOWNLOAD_URL'] = download_url
      ENV['FIG_UPLOAD_URL'] = upload_url

      # Create a simple package
      input = <<-END
        config default
          set FOO=BAR
        end
      END

      # Create a package with publish-only
      out, err, exit_code = 
        fig(%w<--publish simple/1.2.3>, input, :no_raise_on_error => true)
      exit_code.should == 0

      # Check that package exists in upload repo but not in download repo
      upload_path = File.join(upload_dir, 'simple', '1.2.3', Fig::Repository::PACKAGE_FILE_IN_REPO)
      download_path = File.join(download_dir, 'simple', '1.2.3', Fig::Repository::PACKAGE_FILE_IN_REPO)

      File.exist?(upload_path).should be true
      File.exist?(download_path).should be false
    end

    it "(unified repos) publishes to upload URL and downloads from download URL" do
      # Create separate repos
      download_dir, upload_dir = create_test_repos(unified: true)
      download_url = "file://#{download_dir}"
      upload_url = "file://#{upload_dir}"

      # Set up environment for this test
      ENV['FIG_DOWNLOAD_URL'] = download_url
      ENV['FIG_UPLOAD_URL'] = upload_url

      download_url.should_not == upload_url
      FileTest.symlink?(download_dir).should be true
      FileTest.identical?(upload_dir, download_dir)

      # Create a simple package
      input = <<-END
        config default
          set FOO=BAR
        end
      END

      # Create a package with publish-only
      out, err, exit_code = 
        fig(%w<--publish simple/1.2.3>, input, :no_raise_on_error => true)
      exit_code.should == 0

      # Check that package exists in upload repo AND in download repo
      upload_path = File.join(upload_dir, 'simple', '1.2.3', Fig::Repository::PACKAGE_FILE_IN_REPO)
      download_path = File.join(download_dir, 'simple', '1.2.3', Fig::Repository::PACKAGE_FILE_IN_REPO)

      File.exist?(upload_path).should be true
      File.exist?(download_path).should be true
    end
    it "warns when FIG_REMOTE_URL is set alongside the new URLs" do
      # Set up conflicting environment
      ENV['FIG_REMOTE_URL'] = "file:///some/path"
      ENV['FIG_DOWNLOAD_URL'] = "file:///download/path"
      ENV['FIG_UPLOAD_URL'] = "file:///upload/path"

      # We need to mock the $stderr output since that's where the warning goes
      # Capture original stderr and redirect to a StringIO
      original_stderr = $stderr
      $stderr = StringIO.new

      # Create a minimal default.fig file for the test to work
      File.open('default.fig', 'w') { |f| f.puts "config default\nend" }

      # Use Fig::FigRC directly to trigger the warning
      Fig::FigRC.find(nil, ENV['FIG_DOWNLOAD_URL'], ENV['FIG_UPLOAD_URL'],
                    Fig::OperatingSystem.new(false), 
                    FIG_HOME)

      # Get the captured output and restore stderr
      err_output = $stderr.string
      $stderr = original_stderr

      # Check that the warning was emitted
      err_output.should =~ /WARNING: FIG_REMOTE_URL is set but will be ignored/

      # Clean up
      File.unlink('default.fig') if File.exist?('default.fig')
    end

    it "fails when FIG_REMOTE_URL is set but new URLs are missing" do
      # Set up invalid environment
      ENV['FIG_REMOTE_URL'] = "file:///some/path"
      ENV.delete('FIG_DOWNLOAD_URL')
      ENV.delete('FIG_UPLOAD_URL')

      # Create a minimal default.fig file for the test to work
      File.open('default.fig', 'w') { |f| f.puts "config default\nend" }

      # Try to use fig with remote operation, should get error
      out, err, exit_code = fig(%w<--update>, :no_raise_on_error => true)

      # Should fail with clear error message
      exit_code.should_not == 0
      err.should =~ /FIG_REMOTE_URL is set but FIG_DOWNLOAD_URL and\/or FIG_UPLOAD_URL are missing/

      # Clean up
      File.unlink('default.fig') if File.exist?('default.fig')
    end

    it "fails with helpful message when required URL is missing" do
      # Make sure we have no URLs set
      ENV.delete('FIG_REMOTE_URL')
      ENV.delete('FIG_DOWNLOAD_URL')
      ENV.delete('FIG_UPLOAD_URL')

      # Publishing without upload URL
      input = <<-END
        config default
          set FOO=BAR
        end
      END

      out, err, exit_code = fig(%w<--publish simple/1.2.3>, input, :no_raise_on_error => true)
      exit_code.should_not == 0
      err.should =~ /Must set FIG_UPLOAD_URL/

      # Consuming without download URL
      out, err, exit_code = fig(%w<--update>, :no_raise_on_error => true)
      exit_code.should_not == 0
      err.should =~ /Must set FIG_DOWNLOAD_URL/
    end
  end

  after(:all) do
    # Clean up and restore environment
    download_dir = File.join(FIG_SPEC_BASE_DIRECTORY, 'download-repo')
    upload_dir = File.join(FIG_SPEC_BASE_DIRECTORY, 'upload-repo')
    FileUtils.rm_rf(download_dir) if Dir.exist?(download_dir)
    FileUtils.rm_rf(upload_dir) if Dir.exist?(upload_dir)

    # Restore environment variables to default test values
    ENV['FIG_DOWNLOAD_URL'] = FIG_DOWNLOAD_URL
    ENV['FIG_UPLOAD_URL'] = FIG_UPLOAD_URL
    ENV.delete('FIG_REMOTE_URL')
  end
end
