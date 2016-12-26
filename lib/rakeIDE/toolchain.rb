require "pathname"
require_relative "tools.rb"

class Toolchain 

	attr_accessor :working_directory, :executable_name, :target_prefix
	attr_reader :tools, :default_target
	attr_writer :binary_directory, :header_directory, :source_directory, :build_directory, :library_directory

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

		@default_target = "release"
		@tool_options = {}
		@target_actions = {}
	end

	def tools
		[ @compiler, @archive_manager, @linker ].compact
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
				@#{tag}.target = @default_target
				@tool_options.each do |k,v|
					t.set_option k, v
				end
			end
		EOS
	end

	def link
		linker.path |= [library_directory]
		linker.path |= [@library_directory]
		linker.run(obj_files, exec_path)
	end

	def archive name
		archive_manager.run name
	end

	def compile file, out = nil
		compiler.path |= [header_directory]
		compiler.path |= [@header_directory]
		compiler.run(*([file, out].compact)) 
	end

	def available_targets= at
		@available_targets = case at
		when Array
			at.map { |a| a.to_s }
		else
			[at.to_s]
		end | [default_target]
	end

	def available_targets
		@available_targets || [default_target]
	end

	def default_target= t
		@default_target= t.to_s
	end


	def target= t
		unless available_targets and !available_targets.include?(t.to_s)
			@target = t.to_s
			tools.each do |tool|
				tool.target = target
			end
			act = @target_actions[target]
			act.call if act
		else 
			$stderr.puts "Unavailable target [#{t.to_s}]"
		end
	end

	def set hash
		hash.each do |k, v|
			tools.compact.each do |t| 
				t.set_option k, v
			end
		end
		@tool_options.merge! hash
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

	def target_prefix?
		@target_prefix
	end

	def target_prefix
		(@target_prefix and (@target_prefix.is_a?(Boolean) or @target_prefix == "")) ? target : @target_prefix
	end

	def binary_directory
		File.join(*[working_directory, @binary_directory, (target_prefix? ? target_prefix : nil)].compact)
	end

	["source", "build", "library", "header"].each do |tag|
		class_eval <<~EOS
			def #{tag}_directory
				File.join(*[working_directory, @#{tag}_directory || "."].compact)
			end
		EOS
	end

	def target
		@target || default_target.to_s
	end

	def for_target t, &blck
		@target_actions[t.to_s] = blck
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

