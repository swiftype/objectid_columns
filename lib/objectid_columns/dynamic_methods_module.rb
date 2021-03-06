module ObjectidColumns
  # A DynamicMethodsModule is used to add dynamically-generated methods to an existing class.
  #
  # Why do we need a module to do that? Why can't we simply call #define_method on the class itself?
  #
  # We could. However, if you do that, a few problems crop up:
  #
  # * There is no precendence that you can control. If you define a method +:foo+ on class Bar, then that method is
  #   always run when an instance of that class is sent the message +:foo+. The only way to change the behavior of
  #   that class is to completely redefine that method, which brings us to the second problem...
  # * Overriding and +super+ doesn't work. That is, you can't override such a method and call the original method
  #   using +super+. You're reduced to using +alias_method_chain+, which is a mess.
  # * There's no namespacing at all -- at runtime, it's not even remotely clear where these methods are coming from.
  # * Finally, if you're living in a dynamic environment -- like Rails' development mode, where classes get reloaded
  #   very frequently -- once you define a method, it is likely to be forever defined. You have to write code to keep
  #   track of what you've defined, and remove it when it's no longer present.
  #
  # A DynamicMethodsModule fixes these problems. It's little more than a Module that lets you define methods (and
  # helpfully makes #define_method +public+ to help), but it also will include itself into a target class and bind
  # itself to a constant in that class (which magically gives the module a name, too). Further, it also keeps track
  # of which methods you've defined, and can remove them all with #remove_all_methods!. This allows you to construct
  # a much more reliable paradigm: instead of trying to figure out what methods you should remove and add when things
  # change, you can just call #remove_all_methods! and then redefine whatever methods _currently_ should exist.
  #
  # A DynamicMethodsModule also supports class methods; if you define a method with #define_class_method, it will be
  # added to a module that the target class has called +extend+ on (rather than +include+), and hence will show up as
  # a class method on that class. This is useful for the exact same reasons as the base DynamicMethodsModule; it allows
  # for precedence control, use of +super+, namespacing, and dynamism.
  class DynamicMethodsModule < ::Module
    # Creates a new instance. +target_class+ is the Class into which this module should include itself; +name+ is the
    # name to which it should bind itself. (This will be bound as a constant inside that class, not at top-level on
    # Object; so, for example, if +target_class+ is +User+ and +name+ is +Foo+, then this module will end up named
    # +User::Foo+, not simply +Foo+.)
    #
    # If passed a block, the block will be evaluated in the context of this module, just like Module#new. Note that
    # you <em>should not</em> use this to define methods that you want #remove_all_methods!, below, to remove; it
    # won't work. Any methods you add in this block using normal +def+ will persist, even through #remove_all_methods!.
    def initialize(target_class, name, &block)
      raise ArgumentError, "Target class must be a Class, not: #{target_class.inspect}" unless target_class.kind_of?(Class)
      raise ArgumentError, "Name must be a Symbol or String, not: #{name.inspect}" unless name.kind_of?(Symbol) || name.kind_of?(String)

      @target_class = target_class
      @name = name.to_sym

      # Unfortunately, there appears to be no way to "un-include" a Module in Ruby -- so we have no way of replacing
      # an existing DynamicMethodsModule on the target class, which is what we'd really like to do in this situation.

      # Sigh. From the docs for Method#arity:
      #
      # "For Ruby methods that take a variable number of arguments, returns -n-1, where n is the number of required
      # arguments. For methods written in C, returns -1 if the call takes a variable number of arguments."
      #
      # It turns out that .const_defined? is written in C, which means it returns -1 if it takes a variable number of
      # arguments. So we can't check for arity.abs >= 2 here, but rather must look for <= -1...
      if @target_class.method(:const_defined?).arity <= -1
        if @target_class.const_defined?(@name, false)
          existing = @target_class.const_get(@name, false)

          if existing && existing != self
            raise NameError, %{You tried to define a #{self.class.name} named #{name.inspect} on class #{target_class.name},
  but that class already has a constant named #{name.inspect}: #{existing.inspect}}
          end
        end
      else
        # So...in Ruby 1.8.7, .const_defined? and .const_get don't accept the second parameter, which tells you whether
        # to search superclass constants as well. But, amusingly, we're not only not stuck, this is fine: in Ruby
        # 1.8.7, constant lookup doesn't search superclasses, either -- so we're OK.
        if @target_class.const_defined?(@name)
          existing = @target_class.const_get(@name)

          if existing && existing != self
            raise NameError, %{You tried to define a #{self.class.name} named #{name.inspect} on class #{target_class.name},
  but that class already has a constant named #{name.inspect}: #{existing.inspect}}
          end
        end
      end


      @class_methods_module = Module.new
      (class << @class_methods_module; self; end).send(:public, :private)
      @target_class.const_set("#{@name}ClassMethods", @class_methods_module)
      @target_class.send(:extend, @class_methods_module)

      @target_class.const_set(@name, self)
      @target_class.send(:include, self)

      @methods_defined = { }
      @class_methods_defined = { }

      super(&block)
    end

    # Removes all methods that have been defined on this module using #define_method, below. (If you use some other
    # mechanism to define a method on this DynamicMethodsModule, then it will not be removed when this method is
    # called.)
    def remove_all_methods!
      instance_methods.each do |method_name|
        # Important -- we use Class#remove_method, not Class#undef_method, which does something that's different in
        # some important ways.
        remove_method(method_name) if @methods_defined[method_name.to_sym]
      end

      @class_methods_module.instance_methods.each do |method_name|
        @class_methods_module.send(:remove_method, method_name) if @class_methods_defined[method_name]
      end
    end

    # Defines a method. Works identically to Module#define_method, except that it's +public+ and #remove_all_methods!
    # will remove the method.
    def define_method(name, &block)
      name = name.to_sym
      super(name, &block)
      @methods_defined[name] = true
    end

    # Defines a class method.
    def define_class_method(name, &block)
      @class_methods_module.send(:define_method, name, &block)
    end

    # Makes it so you can say, for example:
    #
    #     my_dynamic_methods_module.define_method(:foo) { ... }
    #     my_dynamic_methods_module.private(:foo)
    public :private # teehee
  end
end
