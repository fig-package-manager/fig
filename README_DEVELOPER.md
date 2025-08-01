* If you're trying to figure out what classes are what, run the `simplecov` `rake` task and check out the file groupings.  Since we've got a one class per file policy, a file name maps to the class name.

## Using fig's Test Infrastructure in Layered Implementations

fig includes its test infrastructure in the published gem to
support layered implementations that extend fig's functionality while
maintaining interface compatibility.

### What's Included in the Gem

- **Test utilities** (`lib/fig/spec_utils.rb`) - Core testing helpers including:
  - `fig()` command wrapper for testing external fig processes
  - Environment management (`clean_up_test_environment`, `set_up_test_environment`)
  - Test directory setup and cleanup
  - RSpec configuration and constants

- **Complete test suite** (`spec/**/*`) - All fig compatibility tests for validating interface compliance

### Setting Up Your Layered Implementation

1. **Add fig as a dependency** in your gemspec:
   ```ruby
   spec.add_dependency 'fig', '~> x.y.z'
   spec.add_development_dependency 'rspec', '~> 3'
   ```

2. **Create your spec_helper** to use fig's test utilities:
   ```ruby
   require 'bundler/setup'
   require 'your_fig_implementation/command'
   require 'fig/spec_utils'
   
   # Override constants to use your implementation
   FIG_DIRECTORY = File.expand_path('../bin', __dir__)
   FIG_COMMAND_CLASS = YourFig::Command
   # ... other configuration
   ```

3. **Run compatibility tests** to validate your implementation:
   ```bash
   # Find the fig gem path
   FIG_GEM_PATH=$(bundle exec ruby -e "puts Gem::Specification.find_by_name('fig').gem_dir")
   
   # Run fig tests against your implementation
   bundle exec rspec -I "$FIG_GEM_PATH" "$FIG_GEM_PATH/spec"
   ```

### Expected Results

A fully compatible implementation should pass all fig tests:
- **859 examples, 0 failures, 1 pending** (as of version 2.0.0-alpha.4)
- The pending test is expected (unimplemented feature)
- Some RSpec syntax deprecation warnings are normal

### Benefits

- **Interface validation** - Ensures your implementation maintains compatibility
- **Regression testing** - Catch breaking changes during development  
- **Repository independence** - No need for git submodules or source dependencies
- **Continuous integration** - Easy to integrate into CI pipelines

