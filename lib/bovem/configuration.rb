# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Bovem
  # This class holds the configuration of an applicaton.
  #
  # Extend this class and add valid properties via {property property} method.
  # Example:
  #
  # ```ruby
  # class MyConfiguration << Bovem::Configuration
  #   property :property, :default => "VALUE"
  # end
  #
  # # Configuration file
  # config.property = "VALUE"
  # ```
  class Configuration
    include Lazier::I18n

    # Creates a new configuration.
    #
    # A configuration file is a plain Ruby file with a top-level {Configuration config} object.
    #
    # @param file [String] The file to read.
    # @param overrides [Hash] A set of values which override those set in the configuration file.
    # @param logger [Logger] The logger to use for notifications.
    # @see #parse
    def initialize(file = nil, overrides = {}, logger = nil)
      self.parse(file, overrides, logger)
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

      read_configuration_file(file, logger) if file

      # Apply overrides
      if overrides.is_a?(::Hash) then
        overrides.each_pair do |k, v|
          self.send("#{k}=", v) if self.respond_to?("#{k}=")
        end
      end

      self
    end

    # Defines a new property for the configuration.
    #
    # @param name [Symbol] The name of the property.
    # @param options [Hash] A set of options for the property. Currently, only `:default` (which holds the default value) is supported.
    def self.property(name, options = {})
      options = {} if !options.is_a?(::Hash)

      define_method(name.to_s) do
        self.instance_variable_get("@#{name}") || options[:default]
      end

      define_method("#{name}=") do |value|
        self.instance_variable_set("@#{name}", value)
      end
    end

    private
      # Reads a configuration file.
      #
      # @param file [String] The file to read.
      # @param logger [Logger] The logger to use for notifications.
      def read_configuration_file(file, logger)
        if File.readable?(file) then
          begin
            # Open the file
            path = ::Pathname.new(file).realpath
            logger.info(self.i18n.using(path)) if logger
            self.tap do |config|
              eval(::File.read(path))
            end
          rescue ::Exception => e
            raise Bovem::Errors::InvalidConfiguration.new(self.i18n.configuration.invalid(file))
          end
        else
          raise Bovem::Errors::InvalidConfiguration.new(self.i18n.configuration.not_found(file))
        end
      end
  end
end