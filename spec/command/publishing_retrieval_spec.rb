# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'fig/operating_system'

describe 'Fig' do
  describe 'publishing/retrieval' do
    let(:publish_from_directory)  { "#{FIG_SPEC_BASE_DIRECTORY}/publish-home" }
    let(:lib_directory)           { "#{publish_from_directory}/lib" }
    let(:retrieve_directory)      { "#{CURRENT_DIRECTORY}/retrieve" }

    before(:each) do
      clean_up_test_environment
      set_up_test_environment
      FileUtils.mkdir_p CURRENT_DIRECTORY
      FileUtils.mkdir_p lib_directory
    end

    describe 'retrieves resources' do
      before(:each) do
        IO.write("#{lib_directory}/a library", 'some library')

        another_library = "#{lib_directory}/another library"
        url = 'file://' + File.expand_path(another_library)
        IO.write(another_library, 'some other library')

        fig(
          [
            '--publish',  'prerequisite/1.2.3',
            '--resource', 'lib/a library',
            '--resource', url,
            '--append',   'FOOPATH=@/lib/a library',
            '--append',   'FOOPATH=@/another library'
          ].flatten,
          :current_directory => publish_from_directory
        )
      end

      it 'and produces absolute path warning' do
        input = <<-END
          # Leading slash on path to test warning.
          retrieve FOOPATH->/retrieve/[package]
          config default
            include prerequisite/1.2.3
          end
        END
        out, err = fig(%w<--update-if-missing>, input)
        File.read("#{retrieve_directory}/prerequisite/a library").should ==
          'some library'
        File.read("#{retrieve_directory}/prerequisite/another library").should ==
          'some other library'

        # Check for warning about the leading slash in FOOPATH looking like an
        # absolute path.
        err.should =~ /absolute/
        err.should =~ /relative/
        err.should =~ %r</retrieve/\[package\]>
      end

      it 'and ignores the append statement in the updating config' do
        input = <<-END
          retrieve FOOPATH->retrieve/[package]
          config default
            include prerequisite/1.2.3
            append FOOPATH=@/does/not/exist
          end
        END
        fig(%w<--update-if-missing>, input)
        File.read("#{retrieve_directory}/prerequisite/a library").should ==
          'some library'
        File.read("#{retrieve_directory}/prerequisite/another library").should ==
          'some other library'
      end

      it 'and can tell you where they came from' do
        input = <<-END
          retrieve FOOPATH->retrieve/[package]
          config default
            include prerequisite/1.2.3
          end
        END
        out, * = fig(
          [
            '--update-if-missing',
            '--source-package', "#{retrieve_directory}/prerequisite/a library",
          ],
          input
        )

        out.should == 'prerequisite/1.2.3'
      end
    end

    it 'retrieves resource that is a directory' do
      IO.write("#{lib_directory}/a library", 'some library')
      # To copy the contents of a directory, instead of the directory itself,
      # use '/.' as a suffix to the directory name in 'append'.
      input = <<-END
        grammar v1
        resource 'lib/a library'
        config default
          append FOOPATH=@/lib/.
        end
      END
      fig(
        %w<--publish prerequisite/1.2.3>,
        input,
        :current_directory => publish_from_directory
      )
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig(%w<--update-if-missing>, input)
      File.read("#{retrieve_directory}/prerequisite/a library").should ==
        'some library'
    end

    it 'reports error for missing file in a package' do
      IO.write("#{lib_directory}/a library", 'some library')
      fig(
        [
          %w< --publish  prerequisite/1.2.3 >,
          '--resource', 'lib/a library',
          '--append',   'FOOPATH=@/lib/a library',
        ],
        :current_directory => publish_from_directory
      )
      FileUtils.rm("#{FIG_HOME}/runtime/prerequisite/1.2.3/lib/a library")

      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      out, err, exit_code = fig(
        %w<--update-if-missing>, input, :no_raise_on_error => true
      )
      exit_code.should_not == 0
      err.should =~
        %r<the FOOPATH variable points to a path that does not exist>i
    end

    it 'reports error for retrieve of source and destination being the same path' do
      fig(%w<--publish prerequisite/1.2.3 --set SOME_PATH=.>)

      input = <<-END
        retrieve SOME_PATH->.
        config default
          include prerequisite/1.2.3
        end
      END
      out, err = fig(%w<--update-if-missing>, input)

      err.should =~ %r<skipping copying>i
      err.should =~ %r<" [.] ">x
      err.should =~ %r<to itself>i
    end

    it %q<preserves the path after '//' when copying files into your project directory while retrieving> do
      include_directory = "#{publish_from_directory}/include"
      FileUtils.mkdir_p(include_directory)
      IO.write("#{include_directory}/hello.h", 'a header file')
      IO.write("#{include_directory}/hello2.h", 'another header file')
      input = <<-END
        resource include/hello.h
        resource include/hello2.h
        config default
          append INCLUDE=@//include/hello.h
          append INCLUDE=@//include/hello2.h
        end
      END
      fig(
        %w<--publish prerequisite/1.2.3>,
        input,
        :current_directory => publish_from_directory
      )

      input = <<-END
        retrieve INCLUDE->include2/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig %w<--update>, input

      File.read(
        "#{CURRENT_DIRECTORY}/include2/prerequisite/include/hello.h"
      ).should == 'a header file'
      File.read(
        "#{CURRENT_DIRECTORY}/include2/prerequisite/include/hello2.h"
      ).should == 'another header file'
    end

    it 'updates without there being a copy of the package in the FIG_HOME left there from publishing' do
      include_directory = "#{publish_from_directory}/include"
      FileUtils.mkdir_p(include_directory)
      IO.write("#{include_directory}/hello.h", 'a header file')
      IO.write("#{include_directory}/hello2.h", 'another header file')
      input = <<-END
        resource include/hello.h
        resource include/hello2.h
        config default
          append INCLUDE=@/include/hello.h
          append INCLUDE=@/include/hello2.h
        end
      END
      fig(
        %w<--publish prerequisite/1.2.3>,
        input,
        :current_directory => publish_from_directory
      )

      FileUtils.rm_rf FIG_HOME

      input = <<-END
        retrieve INCLUDE->include2/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig %w<-u>, input

      File.read(
        "#{CURRENT_DIRECTORY}/include2/prerequisite/hello.h"
      ).should == 'a header file'
      File.read(
        "#{CURRENT_DIRECTORY}/include2/prerequisite/hello2.h"
      ).should == 'another header file'
    end

    it 'packages multiple resources' do
      IO.write("#{lib_directory}/a library", 'some library')
      IO.write("#{lib_directory}/a library2", 'some other library')
      input = <<-END
        grammar v1
        resource 'lib/a library'
        resource 'lib/a library2'
        config default
          append FOOPATH="@/lib/a library"
          append FOOPATH="@/lib/a library2"
        end
      END
      fig(
        %w<--publish prerequisite/1.2.3>,
        input,
        :current_directory => publish_from_directory
      )
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig(%w<-m>, input)
      File.read("#{retrieve_directory}/prerequisite/a library").should ==
        'some library'
      File.read("#{retrieve_directory}/prerequisite/a library2").should ==
        'some other library'
    end

    it 'packages multiple resources with wildcards' do
      IO.write("#{lib_directory}/foo.jar", 'some library')
      IO.write("#{lib_directory}/bar.jar", 'some other library')
      input = <<-END
        resource **/*.jar
        config default
          append FOOPATH=@/lib/foo.jar
        end
      END
      fig(
        %w<--publish prerequisite/1.2.3>,
        input,
        :current_directory => publish_from_directory
      )
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig(%w<--update-if-missing>, input)
      File.read("#{retrieve_directory}/prerequisite/foo.jar").should ==
        'some library'
    end

    if Fig::OperatingSystem.unix?
      it 'can publish and retrieve dangling symlinks' do
        FileUtils.rm_rf(publish_from_directory)
        FileUtils.mkdir_p(publish_from_directory)

        File.symlink(
          'does-not-exist', "#{publish_from_directory}/dangling-symlink"
        )
        input = <<-END
          resource dangling-symlink
          config default
            set TEST_FILE=@/dangling-symlink
          end
        END
        fig(
          %w<--publish dependency/1.2.3>,
          input,
          :current_directory => publish_from_directory
        )

        FileUtils.rm_rf(publish_from_directory)
        FileUtils.mkdir_p(publish_from_directory)

        input = <<-END
          retrieve TEST_FILE->.
          config default
            include dependency/1.2.3
          end
        END
        fig(
          %w<--publish dependent/1.2.3>,
          input,
          :current_directory => publish_from_directory
        )

        FileUtils.rm_rf(FIG_HOME)

        File.exist?("#{CURRENT_DIRECTORY}/dangling-symlink") and
          fail 'Symlink should not exist prior to using package.'

        fig(%w<--update dependent/1.2.3 -- echo>)
        File.symlink?("#{CURRENT_DIRECTORY}/dangling-symlink") or
          fail 'Symlink should exist after using package.'
      end
    end

    describe 'cleanup' do
      let(:cleanup_dependency_basename) { 'from-dependency.txt' }
      let(:cleanup_dependency_file)     {
        "#{CURRENT_DIRECTORY}/#{cleanup_dependency_basename}"
      }

      before(:each) do
        FileUtils.rm_rf(publish_from_directory)
        FileUtils.mkdir_p(publish_from_directory)

        FileUtils.touch "#{publish_from_directory}/#{cleanup_dependency_basename}"
        input = <<-END
          resource #{cleanup_dependency_basename}
          config default
            set TEST_FILE=@/#{cleanup_dependency_basename}
          end
        END
        fig(
          %w<--publish dependency/1.2.3>,
          input,
          :current_directory => publish_from_directory
        )

        FileUtils.rm_rf(publish_from_directory)
        FileUtils.mkdir_p(publish_from_directory)

        input = <<-END
          retrieve TEST_FILE->.
          config default
            include dependency/1.2.3
          end
        END
        fig(
          %w<--publish alpha/1.2.3>,
          input,
          :current_directory => publish_from_directory
        )
        fig(
          %w<
            --publish beta/1.2.3
            --no-file
            --set set_something=so-we-have-some-content
          >
        )

        File.exist?(cleanup_dependency_file) and
          fail 'File should not exist prior to using alpha.'

        fig(%w<--update alpha/1.2.3 -- echo>)
        File.exist?(cleanup_dependency_file) or
          fail 'File should exist after using alpha.'
      end

      it 'happens with --update' do
        fig(%w<--update beta/1.2.3 -- echo>)
        File.exist?(cleanup_dependency_file) and
          fail 'File should not exist after using beta.'
      end

      it 'does not happen with --update and --suppress-cleanup-of-retrieves' do
        fig(%w<--update --suppress-cleanup-of-retrieves beta/1.2.3 -- echo>)
        File.exist?(cleanup_dependency_file) or
          fail 'File should exist after using beta.'
      end

      it 'does not happen without --update' do
        fig(%w<beta/1.2.3 -- echo>)
        File.exist?(cleanup_dependency_file) or
          fail 'File should exist after using beta.'
      end
    end

    it 'warns on unused retrieval' do
      set_up_test_environment()

      input = <<-END
        retrieve UNREFERENCED_VARIABLE->somewhere
        config default
          set WHATEVER=SOMETHING
        end
      END
      out, err, exit_code = fig(%w<--update-if-missing>, input)

      err.should =~ /UNREFERENCED_VARIABLE.*was never referenced.*retrieve UNREFERENCED_VARIABLE->somewhere.*was ignored/
    end
  end
end
