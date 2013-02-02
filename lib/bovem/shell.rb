# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Bovem
  # Methods of the {Shell Shell} class.
  module ShellMethods
    # General methods.
    module General
      # Handles general failure of a file/directory method.
      #
      # @param e [Exception] The occurred exception.
      # @param access_error [String|Symbol] The message to show in case of access errors.
      # @param not_found_error [String|Symbol] The message to show in case of a not found entry.
      # @param general_error [String|Symbol] The message to show in case of other errors.
      # @param entries [Array] The list of entries which failed.
      # @param fatal [Boolean] If quit in case of fatal errors.
      # @param show_errors [Boolean] Whether to show errors.
      def handle_failure(e, access_error, not_found_error, general_error, entries, fatal, show_errors)
        error_type = fatal ? :fatal : :error
        message = e.message.gsub(/.+ - (.+)/, "\\1")
        locale = self.i18n.shell

        case e.class.to_s
          when "Errno::EACCES" then @console.send(error_type, locale.send(access_error, message))
          when "Errno::ENOENT" then @console.send(error_type, locale.send(not_found_error, message))
          else show_general_failure(e, general_error, entries, fatal) if show_errors
        end
      end

      # Shows errors when a directory creation failed.
      #
      # @param e [Exception] The occurred exception.
      # @param entries [Array] The list of entries which failed.
      # @param fatal [Boolean] If quit in case of fatal errors.
      def show_general_failure(e, general_error, entries, fatal)
        locale = self.i18n.shell

        @console.error(locale.send(general_error))
        @console.with_indentation(11) do
          entries.each do |entry| @console.write(entry) end
        end
        @console.write(locale.error(e.class.to_s, e), "\n", 5)
        Kernel.exit(-1) if fatal
      end
    end

    # Methods to find or check entries.
    module Read
      # Tests a path against a list of test.
      #
      # Valid tests are every method available in http://www.ruby-doc.org/core-1.9.3/FileTest.html (plus `read`, `write`, `execute`, `exec`, `dir`). Trailing question mark can be omitted.
      #
      # @param path [String] The path to test.
      # @param tests [Array] The list of tests to perform.
      def check(path, tests)
        path = path.ensure_string

        tests.ensure_array.all? {|test|
          # Adjust test name
          test = test.ensure_string.strip

          test = case test
            when "read" then "readable"
            when "write" then "writable"
            when "execute", "exec" then "executable"
            when "dir" then "directory"
            else test
          end

          # Execute test
          test += "?" if test !~ /\?$/
          FileTest.respond_to?(test) ? FileTest.send(test, path) : nil
        }
      end

      # Find a list of files in directories matching given regexps or patterns.
      #
      # You can also pass a block to perform matching. The block will receive a single argument and the path will be considered matched if the blocks not evaluates to `nil` or `false`.
      #
      # Inside the block, you can call `Find.prune` to stop searching in the current directory.
      #
      # @param directories [String] A list of directories where to search files.
      # @param patterns [Array] A list of regexps or patterns to match files. If empty, every file is returned. Ignored if a block is provided.
      # @param by_extension [Boolean] If to only search in extensions. Ignored if a block is provided.
      # @param case_sensitive [Boolean] If the search is case sensitive. Only meaningful for string patterns.
      # @param block [Proc] An optional block to perform matching instead of pattern matching.
      def find(directories, patterns = [], by_extension = false, case_sensitive = false, &block)
        rv = []

        directories = directories.ensure_array.compact {|d| File.expand_path(d.ensure_string) }
        patterns = normalize_patterns(patterns, by_extension, case_sensitive)

        directories.each do |directory|
          if self.check(directory, [:directory, :readable, :executable]) then
            Find.find(directory) do |entry|
              found = patterns.blank? ? true : match_pattern(entry, patterns, by_extension, &block)

              rv << entry if found
            end
          end
        end

        rv
      end

      private
        # Normalizes a set of patterns to find.
        #
        # @param patterns [Array] A list of regexps or patterns to match files. If empty, every file is returned. Ignored if a block is provided.
        # @param by_extension [Boolean] If to only search in extensions. Ignored if a block is provided.
        # @param case_sensitive [Boolean] If the search is case sensitive. Only meaningful for string patterns.
        # @return [Array] The normalized patterns.
        def normalize_patterns(patterns, by_extension, case_sensitive)
          # Adjust patterns
          patterns = patterns.ensure_array.compact.collect {|p| p.is_a?(::Regexp) ? p : Regexp.new(Regexp.quote(p.ensure_string)) }
          patterns = patterns.collect {|p| /(#{p.source})$/ } if by_extension
          patterns = patterns.collect {|p| /#{p.source}/i } if !case_sensitive
          patterns
        end

        # Matches an entry against a set of patterns or a procedure.
        #
        # @param entry [String] The entry to search.
        # @param patterns [Array] A list of regexps or patterns to match files. If empty, every file is returned. Ignored if a block is provided.
        # @param by_extension [Boolean] If to only search in extensions. Ignored if a block is provided.
        # @param block [Proc|nil] An optional block to run instead of pattern matching.
        # @return [Boolean] `true` if entry matched, `false` otherwise.
        def match_pattern(entry, patterns, by_extension, &block)
          catch(:found) do
            if block then
              throw(:found, true) if block.call(entry)
            else
              patterns.each do |pattern|
                throw(:found, true) if pattern.match(entry) && (!by_extension || !File.directory?(entry))
              end
            end

            false
          end
        end
    end

    # Methods to copy or move entries.
    module Write
      # Copies or moves a set of files or directory to another location.
      #
      # @param src [String|Array] The entries to copy or move. If is an Array, `dst` is assumed to be a directory.
      # @param dst [String] The destination. **Any existing entries will be overwritten.** Any required directory will be created.
      # @param operation [Symbol] The operation to perform. Valid values are `:copy` or `:move`.
      # @param run [Boolean] If `false`, it will just print a list of message that would be copied or moved.
      # @param show_errors [Boolean] If show errors.
      # @param fatal [Boolean] If quit in case of fatal errors.
      # @return [Boolean] `true` if operation succeeded, `false` otherwise.
      def copy_or_move(src, dst, operation, run = true, show_errors = false, fatal = true)
        rv = true
        operation = :copy if operation != :move
        operation_s = self.i18n.shell.send(operation)
        single = !src.is_a?(Array)

        if single then
          src = File.expand_path(src)
        else
          src = src.collect {|s| File.expand_path(s) }
        end

        dst = File.expand_path(dst.ensure_string)

        if !run then
          if single then
            @console.warn(self.i18n.shell.copy_move_single_dry(operation_s))
            @console.write(self.i18n.shell.copy_move_from(File.expand_path(src.ensure_string)), "\n", 11)
            @console.write(self.i18n.shell.copy_move_to(dst), "\n", 11)
          else
            @console.warn(self.i18n.shell.copy_move_multi_dry(operation_s))
            @console.with_indentation(11) do
              src.each do |s| @console.write(s) end
            end
            @console.write(self.i18n.shell.copy_move_to_multi(dst), "\n", 5)
          end
        else
          rv = catch(:rv) do
            dst_dir = single ? File.dirname(dst) : dst
            has_dir = self.check(dst_dir, :dir)

            # Create directory
            has_dir = self.create_directories(dst_dir, 0755, true, show_errors, fatal) if !has_dir
            throw(:rv, false) if !has_dir

            if single && self.check(dst, :dir) then
              @console.send(fatal ? :fatal : :error, self.i18n.shell.copy_move_single_to_directory(operation_s, src, dst))
              throw(:rv, false)
            end

            # Check that every file is existing
            src.ensure_array.each do |s|
              if !self.check(s, :exists) then
                @console.send(fatal ? :fatal : :error, self.i18n.shell.copy_move_src_not_found(operation_s, s))
                throw(:rv, false)
              end
            end

            # Do operation
            begin
              FileUtils.send(operation == :move ? :mv : :cp_r, src, dst, {noop: false, verbose: false})
            rescue Errno::EACCES => e
              if single then
                @console.send(fatal ? :fatal : :error, self.i18n.shell.copy_move_dst_not_writable_single(operation_s, src, dst_dir))
              else
                @console.error(self.i18n.shell.copy_move_dst_not_writable_single(operation_s, dst))
                @console.with_indentation(11) do
                  src.each do |s| @console.write(s) end
                end
                Kernel.exit(-1) if fatal
              end

              throw(:rv, false)
            rescue Exception => e
              if single then
                @console.send(fatal ? :fatal : :error, self.i18n.shell.copy_move_error_single(operation_s, src, dst_dir, e.class.to_s, e), "\n", 5)
              else
                @console.error(self.i18n.shell.copy_move_error_multi(operation_s, dst))
                @console.with_indentation(11) do
                  src.each do |s| @console.write(s) end
                end
                @console.write(self.i18n.shell.error(e.class.to_s, e), "\n", 5)
                Kernel.exit(-1) if fatal
              end

              throw(:rv, false)
            end

            true
          end
        end

        rv
      end

      # Copies a set of files or directory to another location.
      #
      # @param src [String|Array] The entries to copy. If is an Array, `dst` is assumed to be a directory.
      # @param dst [String] The destination. **Any existing entries will be overwritten.** Any required directory will be created.
      # @param run [Boolean] If `false`, it will just print a list of message that would be copied or moved.
      # @param show_errors [Boolean] If show errors.
      # @param fatal [Boolean] If quit in case of fatal errors.
      # @return [Boolean] `true` if operation succeeded, `false` otherwise.
      def copy(src, dst, run = true, show_errors = false, fatal = true)
        self.copy_or_move(src, dst, :copy, run, show_errors, fatal)
      end

      # Moves a set of files or directory to another location.
      #
      # @param src [String|Array] The entries to move. If is an Array, `dst` is assumed to be a directory.
      # @param dst [String] The destination. **Any existing entries will be overwritten.** Any required directory will be created.
      # @param run [Boolean] If `false`, it will just print a list of message that would be deleted.
      # @param show_errors [Boolean] If show errors.
      # @param fatal [Boolean] If quit in case of fatal errors.
      # @return [Boolean] `true` if operation succeeded, `false` otherwise.
      def move(src, dst, run = true, show_errors = false, fatal = true)
        self.copy_or_move(src, dst, :move, run, show_errors, fatal)
      end
    end

    # Methods to run commands or delete entries.
    module Execute
      # Runs a command into the shell.
      #
      # @param command [String] The string to run.
      # @param message [String] A message to show before running.
      # @param run [Boolean] If `false`, it will just print a message with the full command that will be run.
      # @param show_exit [Boolean] If show the exit status.
      # @param show_output [Boolean] If show command output.
      # @param show_command [Boolean] If show the command that will be run.
      # @param fatal [Boolean] If quit in case of fatal errors.
      # @return [Hash] An hash with `status` and `output` keys.
      def run(command, message = nil, run = true, show_exit = true, show_output = false, show_command = false, fatal = true)
        rv = {status: 0, output: ""}
        command = command.ensure_string

        # Show the command
        @console.begin(message) if message.present?


        if !run then # Print a message
          @console.warn(self.i18n.shell.run_dry(command))
          @console.status(:ok) if show_exit
        else # Run
          output = ""

          @console.info(self.i18n.shell.run(command)) if show_command
          rv[:status] = ::Open4::popen4(command + " 2>&1") { |pid, stdin, stdout, stderr|
            stdout.each_line do |line|
              output << line
              Kernel.print line if show_output
            end
          }.exitstatus

          rv[:output] = output
        end

        # Return
        @console.status(rv[:status] == 0 ? :ok : :fail) if show_exit
        exit(rv[:status]) if fatal && rv[:status] != 0
        rv
      end

      # Deletes a list of files.
      #
      # @param files [Array] The list of files to remove
      # @param run [Boolean] If `false`, it will just print a list of message that would be deleted.
      # @param show_errors [Boolean] If show errors.
      # @param fatal [Boolean] If quit in case of fatal errors.
      # @return [Boolean] `true` if operation succeeded, `false` otherwise.
      def delete(files, run = true, show_errors = false, fatal = true)
        rv = true
        files = files.ensure_array.compact.collect {|f| File.expand_path(f.ensure_string) }

        if !run then
          @console.warn(self.i18n.shell.remove_dry)
          @console.with_indentation(11) do
            files.each do |file| @console.write(file) end
          end
        else
          rv = catch(:rv) do
            begin
              FileUtils.rm_r(files, {noop: false, verbose: false, secure: true})
              throw(:rv, true)
            rescue => e
              handle_failure(e, :remove_unwritable, :remove_not_found, :remove_error, files, fatal, show_errors)
            end

            false
          end
        end

        rv
      end
    end

    # Methods to interact with directories.
    module Directories
      # Executes a block of code in another directory.
      #
      # @param directory [String] The new working directory.
      # @param restore [Boolean] If to restore the original working directory.
      # @param show_messages [Boolean] Show informative messages about working directory changes.
      # @return [Boolean] `true` if the directory was valid and the code executed, `false` otherwise.
      def within_directory(directory, restore = true, show_messages = false)
        rv = false
        directory = File.expand_path(directory.ensure_string)
        original = Dir.pwd

        rv = enter_directory(directory, show_messages, self.i18n.shell.move_in(directory))
        yield if rv && block_given?
        rv = enter_directory(original, show_messages, self.i18n.shell.move_out(directory)) if rv && restore

        rv
      end

      # Creates a list of directories, included missing parent directories.
      #
      # @param directories [Array] The list of directories to create.
      # @param mode [Fixnum] Initial permissions for the new directories.
      # @param run [Boolean] If `false`, it will just print a list of directories that would be created.
      # @param show_errors [Boolean] If show errors.
      # @param fatal [Boolean] If quit in case of fatal errors.
      # @return [Boolean] `true` if operation succeeded, `false` otherwise.
      def create_directories(directories, mode = 0755, run = true, show_errors = false, fatal = true)
        rv = true

        # Adjust directory
        directories = directories.ensure_array.compact {|d| File.expand_path(d.ensure_string) }

        if !run then # Just print
          show_directory_creation(directories)
        else
          directories.each do |directory|
            rv = rv && try_create_directory(directory, mode, fatal, directories, show_errors)
            break if !rv
          end
        end

        rv
      end

      private
        # Change current working directory.
        #
        # @param directory [String] The directory which move into.
        # @param show_message [Boolean] Whether to show or not message.
        # @param message [String] The message to show.
        # @return [Boolean] `true` if operation succeeded, `false` otherwise.
        def enter_directory(directory, show_message, message)
          begin
            raise ArgumentError if !self.check(directory, [:directory, :executable])
            @console.info(message) if show_message
            Dir.chdir(directory)
            true
          rescue Exception => e
            false
          end
        end

        # Show which directory are going to be created.
        # @param directories [Array] The list of directories to create.
        def show_directory_creation(directories)
          @console.warn(self.i18n.shell.mkdir_dry)
          @console.with_indentation(11) do
            directories.each do |directory| @console.write(directory) end
          end
        end

        # Tries to creates a directory.
        #
        # @param directory [String] The directory to create.
        # @param mode [Fixnum] Initial permissions for the new directories.
        # @param fatal [Boolean] If quit in case of fatal errors.
        # @param directories [Array] The list of directories to create.
        # @param show_errors [Boolean] If show errors.
        # @return [Boolean] `true` if operation succeeded, `false` otherwise.
        def try_create_directory(directory, mode, fatal, directories, show_errors)
          rv = false

          # Perform tests
          if self.check(directory, :directory) then
            @console.send(fatal ? :fatal : :error, self.i18n.shell.mkdir_existing(directory))
          elsif self.check(directory, :exist) then
            @console.send(fatal ? :fatal : :error, self.i18n.shell.mkdir_file(directory))
          else
            rv = create_directory(directory, mode, fatal, directories, show_errors)
          end

          rv
        end

        # Creates a directory.
        #
        # @param directory [String] The directory to create.
        # @param mode [Fixnum] Initial permissions for the new directories.
        # @param fatal [Boolean] If quit in case of fatal errors.
        # @param directories [Array] The list of directories to create.
        # @param show_errors [Boolean] If show errors.
        # @return [Boolean] `true` if operation succeeded, `false` otherwise.
        def create_directory(directory, mode, fatal, directories, show_errors)
          rv = false

          begin # Create directory
            FileUtils.mkdir_p(directory, {mode: mode, noop: false, verbose: false})
            rv = true
          rescue Exception => e
            handle_failure(e, :mkdir_denied, nil, :mkdir_error, directories, fatal, show_errors)
          end

          rv
        end
    end
  end

  # A utility class for most common shell operation.
  #
  # @attr [Console] console # A console instance.
  class Shell
    include Lazier::I18n
    include Bovem::ShellMethods::General
    include Bovem::ShellMethods::Read
    include Bovem::ShellMethods::Write
    include Bovem::ShellMethods::Execute
    include Bovem::ShellMethods::Directories

    attr_accessor :console

    # Returns a unique instance for Shell.
    #
    # @return [Shell] A new instance.
    def self.instance
      @instance ||= ::Bovem::Shell.new
    end

    # Initializes a new Shell.
    def initialize
      @console = ::Bovem::Console.instance
      self.i18n_setup(:bovem, ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/"))
    end
  end
end