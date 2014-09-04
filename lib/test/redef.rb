# Copyright (c) 2013, Nearbuy Systems, Inc.
# All rights reserved.

module Test
end

class Test::Redef
  def initialize(valid_names)
    @valid_names = valid_names
    reset
  end

  def self.rd(methods_to_procs, &block)
    class_wrappers = {}
    methods_to_procs.each do |class_method_name, new_method|
      redef_class, method_name = parse_class_and_method(class_method_name)

      if !self.instance_methods_for(redef_class).include?(method_name)
        raise ArgumentError.new("No method found for #{class_method_name}")
      end

      if new_method == :empty
        new_method = proc { }
      elsif new_method == :wiretap
        new_method = proc { |*args, &block|
          method((method_name.to_s + '_redef').to_sym).call(*args, &block)
        }
      end

      (class_wrappers[redef_class] ||= {})[method_name] = [class_method_name, new_method]
    end
    swap_in_and_run(class_wrappers, block)
  end

  def self.publicize_method(*methods)
    method_syms = []
    methods.each do |class_method_name|
      klass, method_name = parse_class_and_method(class_method_name)
      next if klass.public_instance_methods.include?(method_name)
      method_syms << [klass, method_name]
      klass.send(:public, method_name)
    end

    yield

    method_syms.each {|klass, method_name| klass.send(:private, method_name) }
  end

  def called(method_name=nil)
    return lookup(@called, method_name) || 0
  end

  def called?(method_name=nil)
    return called(method_name) > 0
  end

  def args(method_name=nil)
    return (lookup(@args, method_name) || []).map {|a| a[1] }
  end

  def object(method_name=nil)
    return (lookup(@args, method_name) || []).map {|a| a[0] }
  end

  def call_order
    return @call_order
  end

  def reset(method_name=nil)
    if method_name
      name = lookup_name(method_name)
      @called[name] = 0
      @args[name] = []
    else
      @called = {}
      @args = {}
      @call_order = []
    end
  end

  def [](method_name)
    c = Class.new
    c.instance_exec(self, method_name) do |rs, rs_method_name|
      [:called, :args, :object, :reset, :called?].each do |method|
        define_method(method) { rs.__send__(method, rs_method_name) }
      end
    end
    return c.new
  end

  private
  def self.parse_class_and_method(class_method_name)
    if class_method_name.is_a?(String)
      md = class_method_name.match('^(?<class>[^.#]*)(?<sep>\.|#)(?<method>.*)$')
      method_name = md[:method].to_sym
      klass = string_to_const(md[:class])
      meta_class = (class << klass; self; end)

      redef_class = md[:sep] == '.' ? meta_class : klass
      return redef_class, method_name
    else
      klass_or_obj, method_name = class_method_name
      method_name = method_name.to_sym
      if klass_or_obj.is_a?(Class)
        meta_class = (class << klass_or_obj; self; end)
        return meta_class, method_name
      else
        return klass_or_obj.class, method_name
      end
    end
  end

  def lookup(collection, name)
    return collection[lookup_name(name)]
  end

  def lookup_name(name)
    if name.nil?
      raise ArgumentError if @valid_names.length > 1
      name = @valid_names.first
    end
    if name.instance_of?(Symbol)
      match_methods = @valid_names.select do |m|
        if m.instance_of?(String)
          m =~ /[#.]#{name}$/
        else
          m[1].to_s == name.to_s
        end
      end
      raise ArgumentError.new("Bad method name: #{name}") if match_methods.length != 1
      name = match_methods[0]
    end
    return name
  end

  def record(name, obj, args)
    @called[name] ||= 0
    @called[name] += 1

    @call_order.push(name)

    copy = args
    begin
      copy = Marshal.load(Marshal.dump(args))
    rescue TypeError
    end

    (@args[name] ||= []).push([obj, copy])
  end

  def self.string_to_const(class_name)
    const_parts = class_name.split('::')
    klass = Kernel
    const_parts.each {|p| klass = klass.const_get(p) }
    return klass
  end

  def self.instance_methods_for(klass)
    return klass.instance_methods + klass.private_instance_methods + klass.protected_instance_methods
  end

  @@redef_next_id = 0
  def self.swap_in_and_run(klass_methods, block)
    method_hider = {}
    temporary_methods = []

    redef_state = []
    rs = self.new(klass_methods.values.map {|m| m.values.map(&:first) }.flatten(1))

    klass_methods.each do |klass, methods|
      methods.each do |method_name, method_info|
        name, method = method_info
        hider = method_name.to_s
        while klass.method_defined?(hider) || klass.private_method_defined?(hider)
          hider += '_redef'
        end
        (method_hider[klass] ||={})[method_name] = hider
        raise if hider == method_name #something has gone wrong

        klass.__send__(:alias_method, hider, method_name)
        real_redef_method_name = "__redef_new_method_#{@@redef_next_id}"
        temporary_methods << [klass, real_redef_method_name]
        @@redef_next_id += 1
        klass.__send__(:define_method, real_redef_method_name, method)
        arity = method.arity

        # wrapper to capture arguments
        klass.__send__(:define_method, method_name) do |*args, &block|
          rs.__send__(:record, name, self, args)
          if arity >= 0 && args.length > arity
            args = args.slice(0, arity)
          end
          __send__(real_redef_method_name.to_sym, *args, &block)
        end
      end
    end

    exception = nil
    begin
      ret = block.call(rs)
    rescue Exception
      exception = $!
    end

    klass_methods.each do |klass, methods|
      methods.each do |method_name, method|
        hider = method_hider[klass][method_name]
        silent { klass.__send__(:remove_method, method_name) }
        klass.__send__(:alias_method, method_name, hider)
        klass.__send__(:remove_method, hider)
      end
    end
    temporary_methods.each do |klass, temp_method_name|
      klass.__send__(:remove_method, temp_method_name)
    end

    raise exception if exception

    return ret
  end

  def self.silent
    saved = $VERBOSE
    $VERBOSE = nil

    yield
  ensure
    $VERBOSE = saved
  end
end
