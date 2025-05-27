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
      # Name separate consume and publish directories
      consume_dir = File.join(FIG_SPEC_BASE_DIRECTORY, 'consume-repo')
      publish_dir = File.join(FIG_SPEC_BASE_DIRECTORY, 'publish-repo')

      # Clean up any existing directories
      FileUtils.rm_rf(consume_dir)
      FileUtils.rm_rf(publish_dir)

      # Create the "repositories" based on whether we want unified or not
      FileUtils.mkdir_p(publish_dir)
      FileUtils.mkdir_p(File.join(publish_dir, Fig::Repository::METADATA_SUBDIRECTORY))

      if unified
        FileUtils.ln_s(publish_dir, consume_dir)
      else
        FileUtils.mkdir_p(consume_dir)
        FileUtils.mkdir_p(File.join(consume_dir, Fig::Repository::METADATA_SUBDIRECTORY))
      end

      return consume_dir, publish_dir
    end

    it "(distinct repos) publishes to publish URL and consumes from consume URL" do
      # Create separate repos
      consume_dir, publish_dir = create_test_repos
      consume_url = "file://#{consume_dir}"
      publish_url = "file://#{publish_dir}"

      # Set up environment for this test
      ENV['FIG_CONSUME_URL'] = consume_url
      ENV['FIG_PUBLISH_URL'] = publish_url

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

      # Check that package exists in publish repo but not in consume repo
      publish_path = File.join(publish_dir, 'simple', '1.2.3', Fig::Repository::PACKAGE_FILE_IN_REPO)
      consume_path = File.join(consume_dir, 'simple', '1.2.3', Fig::Repository::PACKAGE_FILE_IN_REPO)

      File.exist?(publish_path).should be true
      File.exist?(consume_path).should be false
    end

    it "(unified repos) publishes to publish URL and consumes from consume URL" do
      # Create separate repos
      consume_dir, publish_dir = create_test_repos(unified: true)
      consume_url = "file://#{consume_dir}"
      publish_url = "file://#{publish_dir}"

      # Set up environment for this test
      ENV['FIG_CONSUME_URL'] = consume_url
      ENV['FIG_PUBLISH_URL'] = publish_url

      consume_url.should_not == publish_url
      FileTest.symlink?(consume_dir).should be true
      FileTest.identical?(publish_dir, consume_dir)

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

      # Check that package exists in publish repo AND in consume repo
      publish_path = File.join(publish_dir, 'simple', '1.2.3', Fig::Repository::PACKAGE_FILE_IN_REPO)
      consume_path = File.join(consume_dir, 'simple', '1.2.3', Fig::Repository::PACKAGE_FILE_IN_REPO)

      File.exist?(publish_path).should be true
      File.exist?(consume_path).should be true
    end
    it "warns when FIG_REMOTE_URL is set alongside the new URLs" do
      # Set up conflicting environment
      ENV['FIG_REMOTE_URL'] = "file:///some/path"
      ENV['FIG_CONSUME_URL'] = "file:///consume/path"
      ENV['FIG_PUBLISH_URL'] = "file:///publish/path"

      # We need to mock the $stderr output since that's where the warning goes
      # Capture original stderr and redirect to a StringIO
      original_stderr = $stderr
      $stderr = StringIO.new

      # Create a minimal default.fig file for the test to work
      File.open('default.fig', 'w') { |f| f.puts "config default\nend" }

      # Use Fig::FigRC directly to trigger the warning
      Fig::FigRC.find(nil, ENV['FIG_CONSUME_URL'], ENV['FIG_PUBLISH_URL'],
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
      ENV.delete('FIG_CONSUME_URL')
      ENV.delete('FIG_PUBLISH_URL')

      # Create a minimal default.fig file for the test to work
      File.open('default.fig', 'w') { |f| f.puts "config default\nend" }

      # Try to use fig with remote operation, should get error
      out, err, exit_code = fig(%w<--update>, :no_raise_on_error => true)

      # Should fail with clear error message
      exit_code.should_not == 0
      err.should =~ /FIG_REMOTE_URL is set but FIG_CONSUME_URL and\/or FIG_PUBLISH_URL are missing/

      # Clean up
      File.unlink('default.fig') if File.exist?('default.fig')
    end

    it "fails with helpful message when required URL is missing" do
      # Make sure we have no URLs set
      ENV.delete('FIG_REMOTE_URL')
      ENV.delete('FIG_CONSUME_URL')
      ENV.delete('FIG_PUBLISH_URL')

      # Publishing without publish URL
      input = <<-END
        config default
          set FOO=BAR
        end
      END

      out, err, exit_code = fig(%w<--publish simple/1.2.3>, input, :no_raise_on_error => true)
      exit_code.should_not == 0
      err.should =~ /Must set FIG_PUBLISH_URL/

      # Consuming without consume URL
      out, err, exit_code = fig(%w<--update>, :no_raise_on_error => true)
      exit_code.should_not == 0
      err.should =~ /Must set FIG_CONSUME_URL/
    end
  end

  after(:all) do
    # Clean up and restore environment
    consume_dir = File.join(FIG_SPEC_BASE_DIRECTORY, 'consume-repo')
    publish_dir = File.join(FIG_SPEC_BASE_DIRECTORY, 'publish-repo')
    FileUtils.rm_rf(consume_dir) if Dir.exist?(consume_dir)
    FileUtils.rm_rf(publish_dir) if Dir.exist?(publish_dir)

    # Restore environment variables to default test values
    ENV['FIG_CONSUME_URL'] = FIG_CONSUME_URL
    ENV['FIG_PUBLISH_URL'] = FIG_PUBLISH_URL
    ENV.delete('FIG_REMOTE_URL')
  end
end
