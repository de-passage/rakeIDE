require "pathname"

class Rakefile 
	CPP_FILE_REGEX = /\.c((pp|xx)?|c)$/
	HPP_FILE_REGEX = /\.(h(((pp|xx)?|h)|inl))$/

	attr_accessor :executable_name, :header_directory, :source_directory, :binary_directory, :build_directory,
		:compiler, :compiler_flags, :compilation_options, :linker_options, :link, :link_path, :include_path, :obj_extension 

	def initialize
		####################################################
		# 
		# 		Configuration
		#
		###################################################

		# Application name
		@executable_name = "app"

		# Project structure
		@header_directory = "include"
		@source_directory = "src"
		@binary_directory = "bin"
		@build_directory = "build"

		# Compiler configuration (gcc only right now)
		@compiler = "g++"
		@compiler_flags = "--std=c++1y -pthread -Wall -Wextra -pedantic"
		@compilation_options = ""
		@link = ""
		@linker = "g++"
		@linker_flags = @compiler_flags.dup
		@link_path = "" # For additional path 
		@include_path = ""

		# Object file extension (why not)
		@obj_extension = ".o"

	end

	# Returns the 
	def exec_path
		@exec_path ||= (File.join binary_directory, executable_name).to_s
	end

	def header_path
		@header_path ||= Pathname.new(header_directory)
	end

	def source_path
		@source_path ||= Pathname.new(source_directory)
	end

	def source_files
		@source_files ||= Dir.glob(source_path + "**/*").reject { |f| f.to_s !~ CPP_FILE_REGEX }
	end

	def source_directory_structure
		@source_directory_structure ||= Dir.glob(source_path + "**/").map { |e| e.to_s }
	end

	def obj_directory_structure
		@obj_directory_structure ||= source_directory_structure.map { |e| e.sub(source_directory, build_directory) }.reject { |e| e == build_directory }
	end

	def obj_files
		@obj_files ||= source_files.map { |e| e.sub(CPP_FILE_REGEX, obj_extension).sub(source_directory, build_directory) }
	end

	def included_files
		@included_files ||= Pathname.glob(header_path + "**/*").map{|d|d.relative_path_from(header_path).to_s}.reject { |f| f.to_s !~ HPP_FILE_REGEX }
	end

	# Finds the source file corresponding to the object file processed in parameters
	def resolve_obj_source_file obj
		o = Regexp.quote(obj.sub(obj_extension, "").sub(build_directory, source_directory))
		raise "Conflicting source file names for #{obj}" if source_files.count { |e| e =~ /#{o}/ } > 1 
		source_files.find { |e| e =~ /#{o}#{CPP_FILE_REGEX}/ } 
	end

	# Returns a list of local modules included in the given file
	def all_hpp_files cpp
		ret = []
		File.open(cpp) do |f|
			f.each do |l|
				if m = l.match(/#include\s+(?:"|<)(.+)(?:"|>).*/)
					ret << m[1]
				end
			end
		end
		reg = /#{included_files.map { |hpp| Regexp.quote(hpp) }.join("|")}/
		ret.select { |f| f =~ reg }.map { |f| (header_path + f).to_s }
	end

	####################################################
	# 
	# 		Utils
	#
	###################################################


	# Build a list of all dependencies for an object file, including
	# build directory structure, associated source file and infinitely
	# nested include directives
	def all_obj_dependencies obj
		cpp = resolve_obj_source_file(obj)
		# Build a list of hpp files 
		hpp = all_hpp_files(cpp)
		loop do 
			# Go one level deeper excluding those done already
			new_files = []
			hpp.each do |h| 
				# We don't want to process twice the same file 
				# to avoid infinite loops
				new_files += (all_hpp_files(h) - hpp - new_files)
			end
			# repeat until nothing comes out
			break if new_files == []
			hpp += new_files
		end
		obj_directory_structure + hpp + [cpp]
	end
end

Config = Rakefile.new

####################################################
# 
# 		Tasks
#
###################################################

task :default => :build

desc "Compile the files and build the executable"
task :build => Config.exec_path 

file Config.exec_path => Config.obj_files + [Config.binary_directory] do
	sh "#{Config.linker} #{Config.linker_flags} #{Config.linker_options} -o #{Config.exec_path} #{Config.obj_files.join(" ")} #{Config.link}"
end

directory Config.binary_directory

Config.obj_directory_structure.each { |d| directory d }

desc "Rebuild the executable from scratches"
task :rebuild => [:clean, :build]

namespace :rebuild do 
	desc "Rebuild the executable then run it"
	task :run => [:rebuild, :run]
end

namespace :build do
	desc "Build the executable then run it"
	task :run => [:build, :run]
end

desc "Run the executable"
task :run => Config.exec_path do
	sh Config.exec_path
end

file Config.exec_path

rule Config.obj_extension => proc { |obj| Config.all_obj_dependencies(obj) } do |t|
	sh "#{Config.compiler} #{Config.flags} -I#{Config.header_directory} #{Config.compilation_options} -c #{t.prerequisites[-1]} -o #{t.name}"
end

desc "Remove all object files"
task :clean do 
	rm_f Config.obj_files
end

desc "Clean all object files and remove the executable"
task :purge => :clean do
	rm_f Config.exec_path
end

desc "Shows some debug informations"
task 
