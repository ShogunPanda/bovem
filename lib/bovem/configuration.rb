# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

module Bovem
  # This class holds the configuration of an application.
  #
  # Extend this class and add valid properties via {property property} method.
  # Example:
  #
  # ```ruby
  # class MyConfiguration << Bovem::Configuration
  #   property :property, default: "VALUE"
  # end
  #
  # # Configuration file
  # config.property = "VALUE"
  # ```
  #
  # @attribute [r] i18n
  #   @return [I18n] A i18n helper.
  class Configuration < Lazier::Configuration
    attr_reader :i18n

    # Creates a new configuration.
    #
    # A configuration file is a plain Ruby file with a top-level {Configuration config} object.
    #
    # @param file [String] The file to read.
    # @param overrides [Hash] A set of values which override those set in the configuration file.
    # @param logger [Logger] The logger to use for notifications.
    # @see #parse
    def initialize(file = nil, overrides = {}, logger = nil)
      super()

      @i18n = Bovem::I18n.new(root: "bovem.configuration", path: Bovem::Application::LOCALE_ROOT)
      parse(file, overrides, logger)
    end

    # Parses a configuration file.
    #
    # A configuration file is a plain Ruby file with a top-level {Configuration config} object.
    #
    # Example:
    #
    # ```ruby
    # config.property = "VALUE"
    # ```
    #
    # @param file [String] The file to read.
    # @param logger [Logger] The logger to use for notifications.
    # @param overrides [Hash] A set of values which override those set in the configuration file.
    def parse(file = nil, overrides = {}, logger = nil)
      file = file.present? ? File.expand_path(file) : nil

      if file
        raise(Bovem::Errors::InvalidConfiguration, i18n.not_found(file)) unless File.readable?(file)
        read_configuration_file(file, logger)
      end

      # Apply overrides
      overrides.each_pair { |k, v| send("#{k}=", v) if respond_to?("#{k}=") } if overrides.is_a?(::Hash)

      self
    end

    private

    # :nodoc:
    # rubocop:disable RescueException
    def read_configuration_file(file, logger)
      # Open the file
      path = file =~ /^#{File::SEPARATOR}/ ? file : ::Pathname.new(file).realpath
      logger.info(i18n.using(path)) if logger
      eval_file(path)
    rescue Exception
      raise(Bovem::Errors::InvalidConfiguration, i18n.invalid(file))
    end
    # rubocop:enable RescueException

    # :nodoc:
    def eval_file(path)
      # rubocop:disable UnusedBlockArgument, Eval
      tap { |config| eval(File.read(path)) }
      # rubocop:enable UnusedBlockArgument, Eval
    end
  end
end
