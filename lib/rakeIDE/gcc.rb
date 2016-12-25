require_relative "tools.rb"

module Tools
	# General characteristics of GCC based compilers
	module GCC
		attr_writer :object_file_extension, :header_file_extensions, :source_file_extensions

		# Paths to inspect
		def paths
			@paths ||= []
		end

		def paths= p
			@paths = case p
					 when Array
						 p
					 else
						 [p]
					 end
		end


		def object_file_extension
			@object_file_extension ||= ".o"
		end

		# Name of the compiler
		def name 
			"gcc"
		end

		# Sets whether the pthread option should be set
		# when compiling or linking
		def multi_threaded= b
			case b
			when true
				options << "-pthread"
			when false
				options.delete("-pthread")
			end
		end

		# Extension of header files
		def header_file_extensions 
			/\.h$/
		end

		# Extension for source files
		def source_file_extensions
			/\.c$/
		end

	end

	module Compiler
		class GCC < Base 
			include Tools::GCC

			# Returns an array of individual items forming a command
			def command file, out = nil
				[name, *options, *include_path, "-c", file] + (out ? ["-o", out] : [])
			end

			# Returns a list of option
			def include_path
				paths.map { |p| "-I" + p }
			end

			# Compute the local dependencies of a file
			def source_dependencies cpp
				ret = []
				File.open(cpp) do |f|
					f.each do |l|
						if m = l.match(/#include\s+(?:"|<)(.+)(?:"|>).*/)
							ret << m[1]
						end
					end
				end
				ret
			end
		end
	end

	module Linker
		class GCC < Base
			include Tools::GCC

			def command files, out
				[name, *options, "-o", out, *files, *_libraries]
			end

			def library_path
				paths.map { |p| "-L" + p }
			end

			def libraries
				@libraries ||= []
			end

			private def _libraries
				libraries.map { |l| "-l" + l }
			end
		end
	end
end
