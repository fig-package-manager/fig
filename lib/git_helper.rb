# TODO spec test for this

module GitHelper
  def self.sha1(commitish = 'HEAD', opts = [ '--short '])
    sha = `git rev-parse #{opts.join(' ')} #{commitish}`.chomp

    # add "-dirty" if commitish is 'HEAD' and the workspace has changes
    sha += '-dirty' if commitish == 'HEAD' && self.dirty?

    sha.empty? ? nil : sha
  end

  def self.dirty?
    changes = `git status --porcelain -uno`
    !changes.empty?
  end
end
