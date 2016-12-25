require_relative "gcc.rb"

module Tools

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
		class GXX < GCC
			include Tools::GXX
		end
	end

	module Linker
		class GXX < GCC
			include Tools::GXX
		end
	end

end
