require "pathname"

module Tools

	class Base
		attr_accessor :options, :safe_mode
		attr_reader :type

		def initialize type
			@options = []
			@type = type
		end

		def command
			raise "Invalid #{type}"
		end

		def run *args
			command(*args)
		end

		def method_missing s, *args, &blck
			return if @safe_mode
			super(s, *args, &blck)
		end
	end

	module GCC
		attr_writer :object_file_extension

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

		def name 
			"gcc"
		end

		def multi_threaded= b
			case b
			when true
				options << "-pthread"
			when false
				options.delete("-pthread")
			end
		end

		def header_file_extensions 
			".h"
		end

		def source_file_extensions
			".cpp"
		end

	end

	module GXX
		include GCC

		def name
			"g++"
		end

		def header_file_extensions
			/\.(h(((pp|xx)?|h)|inl))$/
		end

		def source_file_extensions
			/\.c((pp|xx)?|c)$/
		end
	end

	module Compiler
		class Base < Tools::Base

			def initialize
				super(:compiler)
			end

			def source_file_extensions
				raise "No extension file specified"
			end
		end

		class GCC < Base 
			include Tools::GCC

			def command file, out = nil
				[name, *options, *include_path, "-c", file] + (out ? ["-o", out] : [])
			end

			def include_path
				paths.map { |p| "-I" + p }
			end

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

		class GXX < GCC
			include Tools::GXX
		end
	end

	class Linker
		class Base < Tools::Base
			def initialize 
				super(:linker)
			end 
		end

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


		class GXX < GCC
			include Tools::GXX
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

class Toolchain 

	attr_accessor :working_directory, :executable_name, :default_build
	attr_reader :tools
	attr_writer :binary_directory, :header_directory, :source_directory, :build_directory, :library_directory, :build_type

	def initialize
		@working_directory = nil

		# Application name
		@executable_name = "app"

		# Project structure
		@header_directory = "include"
		@source_directory = "src"
		@binary_directory = "bin"
		@build_directory = "build"
		@library_directory = "lib"

		@default_build = "release"
	end

	def tools
		[ @compiler, @attr_accessor, @linker ].compact
	end
	["compiler", "archive_manager", "linker"].each do |tag|
		class_eval <<~EOS
			def #{tag}
				@#{tag} ||= Tools::#{tag.capitalize.gsub(/_([a-z])/) { $1.upcase } }::Base
			end

			def #{tag}= t
				@#{tag} = case t
				when Class
					t.new
				else
					t
				end
			end
		EOS
	end

	def link
		linker.paths |= [library_directory]
		linker.paths |= [@library_directory]
		linker.run(obj_files, exec_path)
	end

	def archive name
		archive_manager.run name
	end

	def compile file, out = nil
		compiler.paths |= [header_directory]
		compiler.paths |= [@header_directory]
		compiler.run(*([file, out].compact)) 
	end

	def set hash
		hash.each do |k, v|
			tools.compact.each do |t| 
				t.safe_mode = true
				t.send("#{k}=", v)
				t.safe_mode = false
			end
		end
	end



	# Returns a string containing a path to the executable to be built
	def exec_path
		File.join binary_directory, executable_name
	end

	# Returns a Pathname containing 
	def header_path
		@header_path ||= Pathname.new(header_directory)
	end

	def source_path
		@source_path ||= Pathname.new(source_directory)
	end

	def source_files
		@source_files ||= Dir.glob(source_path + "**/*").reject { |f| f.to_s !~ compiler.source_file_extensions }
	end

	def source_directory_structure
		@source_directory_structure ||= Dir.glob(source_path + "**/").map { |e| e.to_s }
	end

	def obj_directory_structure
		@obj_directory_structure ||= source_directory_structure.map { |e| e.sub(source_directory, build_directory) }.reject { |e| e == build_directory }
	end

	def obj_files
		@obj_files ||= source_files.map { |e| e.sub(compiler.source_file_extensions, obj_extension).sub(source_directory, build_directory) }
	end

	def included_files
		@included_files ||= Pathname.glob(header_path + "**/*").map{|d|d.relative_path_from(header_path).to_s}.reject { |f| f.to_s !~ compiler.header_file_extensions }
	end

	def obj_extension
		@obj_extension || @compiler.object_file_extension
	end

	def binary_directory
		File.join(*[working_directory, @binary_directory, build_type].compact)
	end

	["source", "build", "library", "header"].each do |tag|
		class_eval <<~EOS
			def #{tag}_directory
				File.join(*[working_directory, @#{tag}_directory || "."].compact)
			end
		EOS
	end

	def build_type
		@build_type || default_build
	end



	# Finds the source file corresponding to the object file processed in parameters
	#
	def resolve_obj_source_file obj
		o = Regexp.quote(obj.sub(obj_extension, "").sub(build_directory, source_directory))
		raise "Conflicting source file names for #{obj}" if source_files.count { |e| e =~ /#{o}/ } > 1 
		source_files.find { |e| e =~ /#{o}#{compiler.source_file_extensions}/ } 
	end




	# Returns a list of local modules included in the given file
	def source_dependencies cpp
		return [] if included_files.empty?
		reg = /#{included_files.map { |hpp| Regexp.quote(hpp) }.join("|")}/
		compiler.
			source_dependencies(cpp).
			select { |f| f =~ reg }.
			map { |f| (header_path + f).to_s }
	end





	# Build a list of all dependencies for an object file, including
	# build directory structure, associated source file and infinitely
	# nested include directives
	def all_obj_dependencies obj
		cpp = resolve_obj_source_file(obj)
		# Build a list of hpp files 
		hpp = source_dependencies(cpp)
		loop do 
			# Go one level deeper excluding those done already
			new_files = []
			hpp.each do |h| 
				# We don't want to process twice the same file 
				# to avoid infinite loops
				new_files += (source_dependencies(h) - hpp - new_files)
			end
			# repeat until nothing comes out
			break if new_files == []
			hpp += new_files
		end
		obj_directory_structure + hpp + [cpp]
	end
end

IDE = Toolchain.new
IDE.compiler = Tools::Compiler::GXX
IDE.linker = Tools::Linker::GXX

IDE.compiler.options = ["--std=c++1y", "-Wall", "-Wextra", "-pedantic"]

####################################################
# 
# 		Tasks
#
###################################################

desc "Defines the target project, defaults to the current directory if not called"
task :target, :working_directory do |t, args|
	# Sets the working directory for the IDE
	wd = args[:working_directory]
	raise "#{wd} is not a directory" unless wd.nil? or Dir.exist? wd
	IDE.working_directory = wd

	# Task definition needs to be delayed to account for the change in 
	# internal state in IDE

	# Define the task for the executable
	file IDE.exec_path => IDE.obj_files + [IDE.binary_directory] do
		sh(*IDE.link)
	end

	# Define the task for the binary directory
	directory IDE.binary_directory

	# Define the tasks for the subfolders of the build directory
	IDE.obj_directory_structure.each { |d| directory d }

end

task :default => :build

desc "Compile the files and build the executable"
task :build => "target" do
	Rake::Task[IDE.exec_path].invoke
end

desc "Rebuild the executable from scratches"
task :rebuild => [:clean, :build]

desc "Run the executable"
task :run do
	unless File.exist? IDE.exec_path
		$stderr.puts "The executable #{IDE.exec_path} doesn't exist, please run 'rake build' first."
		exit
	end
	sh IDE.exec_path
end

desc "Remove all object files"
task :clean do 
	rm_f IDE.obj_files
end

desc "Clean all object files and remove the executable"
task :purge => :clean do
	rm_f IDE.exec_path
end


# Define the rule for the object files
# This one uses a proc so the execution is already delayed enough to 
# allow us to define it here (doesn't matter really)
rule IDE.obj_extension => proc { |obj| IDE.all_obj_dependencies(obj) } do |ts|
	sh(*IDE.compile(ts.prerequisites[-1], ts.name))
end
