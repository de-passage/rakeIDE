module Tools

	class Base
		attr_accessor :options, :safe_mode
		attr_reader :type

		def initialize type
			@options = []
			@type = type
		end

		# To be implemented by derived classes
		def command
			raise "Invalid #{type}"
		end

		# Returns an array of individual items forming a command 
		# depending on the arguments
		def run *args
			command(*args)
		end

		def method_missing s, *args, &blck
			return if @safe_mode
			super(s, *args, &blck)
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
		end
	end
end
