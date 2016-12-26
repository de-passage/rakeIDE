module Tools

	class Base
		attr_accessor :options, :target
		attr_reader :type

		def initialize type
			@options = []
			@type = type
			@path = []
		end

		# To be implemented by derived classes
		def command
			raise "Invalid #{type}"
		end

		# Returns an array of individual items forming a command 
		# depending on the arguments
		def run *args
			command(*args).flatten
		end

		def method_missing s, *args, &blck
			return if @safe_mode
			super(s, *args, &blck)
		end
		
		# Paths to inspect
		def path
			@path ||= []
		end

		def path= p
			@path = case p
					 when Array
						 p
					 else
						 [p]
					 end
		end

		def set_option name, value
			@safe_mode = true
			send("#{name}=", value)
			@safe_mode = false
		end
	end


	module Compiler
		class Base < Tools::Base

			def initialize
				super(:compiler)
			end

			# To be implemented by derived classes
			#
			# Returns a Regexp matching file name extensions
			# corresponding to source files
			def source_file_extensions
				raise "No extension file specified"
			end
		end
	end

	module Linker
		class Base < Tools::Base
			def initialize 
				super(:linker)
			end 
		end
	end

	module ArchiveManager
		class Base < Tools::Base
			def initialize
				super(:archive_manager)
			end
		end

		class Ar < Base
			attr_reader :name
			def initialize
				@name = ["ar", "rvs"]
			end

			def command files, target
				[*name, target, *files]
			end
		end
	end
end
