# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# A collection of utilities for developers.
module Bovem
  # The current version of bovem, according to semantic versioning.
  #
  # @see http://semver.org
  module Version
    # The major version.
    MAJOR = 1

    # The minor version.
    MINOR = 0

    # The patch version.
    PATCH = 0

    # The current version number of Bovem.
    STRING = [MAJOR, MINOR, PATCH].compact.join(".")
  end
end