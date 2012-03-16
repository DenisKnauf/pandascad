#!/usr/bin/env ruby

class OpenSCAD
	def initialize indent = nil, &out
		@indent, @out = indent || 0, out || STDOUT
		@vars = {}
	end

	def - var
		var = var.to_s
		self << __indent__ << var << ' = ' << @vars[var] << ";\n"
	end

	def + code
		Code.new code.to_s
	end

	def << o, &block
		if block_given?
			yield self.class.new( @indent+1)
		else
			@out << o
		end
	end

	def __indent__ i = nil
		@indent += i  if i
		"\t"*@indent
	end

	def module meth, *args, &block
		@vars = (vars = @vars).dup
		args = args.collect do |arg|
			arg = arg.to_s
			dim = []
			while arg =~ /(.*)\[(\d+)\]$/
				dim.push $2.to_i
				arg = $1
			end
			arg = Code.new arg
			gen = lambda do |ds, is|
				if ds.empty?
					Code.new "#{arg}#{is.collect{|i|"[#{i}]"}.join}"
				else
					d, *ds = ds
					List[ *d.times.collect {|i| gen[ ds, is+[i]] }]
				end
			end
			@vars[arg] = gen[dim,[]]
			arg
		end
		method_missing "module #{meth}", *args, &(block||lambda{|*_,&e|})
		@vars = vars
	end

	def method_missing meth, *args, &block
		meth = meth.to_s
		case meth
		when /=$/ # setting variable
			#self << __indent__ << meth << args[0].to_openscad << ";\n"
			@vars[ meth[0...-1]] = args[0]
		when *@vars.keys # reading variable
			@vars[ meth]
		else # method-calling
			bkvars = @vars.dup
			nargs = []
			args.each do |arg|
				case arg
				when Hash
					arg.each do |k,v|
						nargs.push "#{k}=#{v.to_openscad}"
						@vars[k.to_s] = Code.new k.to_s
					end
				else nargs.push arg.to_openscad
				end
			end
			join = case meth
				when 'for'
					r = ",\n" << __indent__(+2)
					@indent -= 2
					r
				else ', '
				end
			self << __indent__ << meth
			self << "(" << nargs.join( join) << ')'  unless 'else' == meth
			if block_given?
				@indent += 1
				self << " {\n"
				yield
				@indent -= 1
				self << __indent__ << "}\n"
			else
				self << ";\n"
			end
			@vars = bkvars
		end
	end

	class List < Array
		def self.[]( *as)  super *as.collect {|v| Array === v ? self[ *v] : v }  end
		def depth()  List === (o = self[0]) ? 1+o.depth : 1  end
		def map( &e)  dup.map! &e  end
		def collect( &e)  dup.collect! &e  end

		def operation o = nil, &e
			o = case o
				when List then o
				when Array then self.class[ *o]
				else o
				end
			if List === o
				case depth <=> o.depth
				when -1 then o.collect {|b| operation b, &e }
				when  1 then collect {|a| a.operation o, &e }
				else
					case depth
					when 1 then self.class[ *zip( o)].collect {|a,b| e[a,b] }
					else self.class[ *zip( o)].collect {|a,b| a.operation b, &e }
					end
				end
			else
				case depth
				when 1 then collect {|v| e[v,o] }
				else collect {|v| v.operation o, &e }
				end
			end
		end

		def s_operation( s, o)  operation( o) {|a,b| Code.new "(#{a.to_openscad}#{s}#{b})" }  end
		def +( o) operation( o) {|a,b| a+b } end
		def -( o) operation( o) {|a,b| a-b } end
		def *( o) operation( o) {|a,b| a*b } end
		def /( o) operation( o) {|a,b| a/b } end
		def %( o) operation( o) {|a,b| a%b } end
		def -@() operation {|a| -a } end
		def +@() operation {|a| +a } end

		def [] i
			case i
			when Integer then super i
			else Code.new "#{self.to_openscad}[#{i}]"
			end
		end

		def to_openscad
			"[#{collect(&:to_openscad).join', '}]"
		end
	end

	class Code < String
		def new( a)  super a.to_s  end
		def to_openscad()  to_s  end
		def s_operation s, o
			case o
			when List
				o.operation( self) {|a,b| self.class.new "(#{b}#{s}#{a.to_openscad})" }
			else self.class.new "(#{to_openscad}#{s}#{o.to_openscad})"
			end
		end
		def +( o) 0 == o ? self : s_operation( :+, o) end
		def -( o) 0 == o ? self : s_operation( :-, o) end
		def *( o) 1 == o ? self : s_operation( :*, o) end
		def /( o) 1 == o ? self : s_operation( :/, o) end
		def %( o) s_operation( :%, o) end
		def -@()  s = self.dup; s[0,0] = '-'; s end
		def +@()  s = self.dup; s[0,0] = '+'; s end
		def []( i) self.class.new "#{self}[#{i}]" end
	end

	def []( *args)  List[ *args]  end
end

class Object
	def to_openscad()  inspect  end
end

class Range
	def to_openscad()  "[#{self.begin}:#{self.end}]"  end
end
