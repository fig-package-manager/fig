# Code changes

* Make use of Statement#is_environment_variable?().
* Rename not_found_error to something like url_not_found_error.
* Multiple places directly instantiate Unparser::V0.  Need to have a central place to determine unparse grammar.
* Retrieve statements should validate their paths the same way that path statements do.
* Periodically `ack '\bTODO:'` and fix what we can.

## v1.0

Whitespace/quoting stuff in order to have a working command line.  It is currently possible to publish packages using `--set`/`--append`/`--resource`/`--archive` that can't be parsed.

* **Big yak in need of a trim**: URL en/de-coding of assets, e.g. `archive http://example.com/hi%20there`.
* Asset statements
    * In package definition
    * On command-line
* Environment variable statements
    * In package definition
    * On command-line
* Fix all "pending" tests.
* Quoting of retrieves: post 1.0? Although... this really should work along with environment variable statements.  Need to figure out escaping of "[package]".

# Tests

* Put spaces into filenames in all the tests.  Can't do this until environment variable statements can handle whitespace.
* Remove use of exit_code from all tests invoking `fig()` without `:no_raise_on_error`.
* Test quoting of asset command-line options.
* Test actual asset globbing/non-globbing of disk files.
* Test that having a # in a value requires v1 grammar.
* Test that v0 grammar results in unquoted "resources.tar.gz" and v1 grammar quotes it.
* Get all the tests' `$PWD` out of `spec/runtime-work` and into `spec/runtime-work/userhome` so that we're properly testing paths to things.  Too many of the tests are counting on files being in `$HOME`.
* Repository class coverage doesn't seem to be hitting resources with URLs.
* Serious testing of which grammar version stuff gets unparsed into.

# Documentation

* Clarify "URLs" that are either file-or-URL or proper URLs.
* Whack wiki asset descriptions.
* Document "looks like a URL".
* Describe retrieve behavior in the presence of symlinks.
* Document repository locking.
* Document that command statements are only processed in published packages or with `--run-command-statement`.
* Document quoting.

# Paranoia / things to think about

* Should the grammar statement keyword be something other than "grammar"?
* Check "@" escapes with `--set`/`--append`.
* Look into Simplecov CSV outputter for diffing runs.
* Double check where archives are extracted under the influence of a retrieve.
