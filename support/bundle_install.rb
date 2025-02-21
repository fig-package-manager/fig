require 'bundler'
require 'stringio'

# capture stdout & stderr
def capture_output
  orig_stdout, orig_stderr = $stdout, $stderr
  $stderr = $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout, $stderr = orig_stdout, orig_stderr
end



def install_and_capture_native_gems
  native_gems = []

  out = ""
  begin
    out = capture_output do
      Bundler.reset!
      bundle_def = Bundler::Definition.build('Gemfile', 'Gemfile.lock', nil)
      installer = Bundler::Installer.install(Bundler.root, bundle_def)
    end
  rescue Bundler::BundlerError => e
      puts "Bundler error: #{e.message}"
      exit 1
  end

  out.each_line do |line|
    if line =~ /Installing (.*) (.*) with native extensions/
      native_gems << { name: $1, version: $2 }
    end
  end

  return native_gems, out
end

native_gems, installer_output = install_and_capture_native_gems

puts installer_output

puts "\n\nGems that required compilation at install time:"
if native_gems.empty?
  puts 'No native gems.'
else
  native_gems.each { |gem| puts "  #{gem[:name]}" }
end
