require_relative "rakeIDE/toolchain.rb"

module IDE
	@@toolchain = Toolchain.new
	def self.method_missing s, *args, &blck
		@@toolchain.send(s, *args, &blck)
	end
end

####################################################
# 
# 		Tasks
#
###################################################

desc "Defines the source project, defaults to the current directory if not called"
task :source, :working_directory do |_, args|
	# Sets the working directory for the IDE
	wd = args[:working_directory]
	raise "#{wd} is not a directory" unless wd.nil? or Dir.exist? wd
	IDE.working_directory = wd if wd
end

desc "Defines the target to build."
task :target, :t do |_, args|
	IDE.target = args[:t] || IDE.default_target
end

task :setup => ["source", :target] do
	# Task definition needs to be delayed to account for the change in 
	# internal state in IDE

	# Define the task for the executable
	file IDE.exec_path => IDE.obj_files + [IDE.binary_directory] do
		sh(*IDE.link)
	end

	# Define the task for the binary directory
	directory IDE.binary_directory unless IDE.binary_directory == ""

	# Define the tasks for the subfolders of the build directory
	IDE.obj_directory_structure.each { |d| directory d unless d == ""}

	# Define the rule for the object files
	rule IDE.obj_extension => proc { |obj| IDE.all_obj_dependencies(obj) } do |ts|
		sh(*IDE.compile(ts.prerequisites[-1], ts.name))
	end
end

task :default => :build

desc "Compile the files and build the executable"
task :build => :setup do
	Rake::Task[IDE.exec_path].invoke
end

desc "Rebuild the executable from scratches"
task :rebuild => [:clean, :build]

desc "Run the executable"
task :run => :setup do
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


