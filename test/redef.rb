# Copyright (c) 2013, Nearbuy Systems, Inc.
# All rights reserved.
require 'test/unit'
require 'test/redef'

class RedefTest < Test::Unit::TestCase
  def test_redef
    a = TestClass.new
    b = TestClass.new
    assert_equal( 'orig', a.test_method ) # sanity
    assert_equal( 'orig', b.test_method )

    Test::Redef.rd 'TestClass#test_method' => proc { 'new' } do |r|
      assert( !r.called? )

      assert_equal( 'new', a.test_method('foo') )
      assert_equal( 'new', b.test_method )
      assert( r.called? )
      assert_equal( 2, r.called )
      assert_equal( [a, b], r.object )
      assert_equal( [['foo'], []], r.args )

      r.reset
      assert_equal( [], r.args )
      assert_equal( 0, r.called )

      assert_equal( 'new', a.test_method('foo') )
      assert_equal( [['foo']], r.args )
      assert_equal( 1, r.called )
    end

    assert_equal( 'orig', a.test_method )
    assert_equal( 'orig', b.test_method )

    check_self = lambda {|*args|
      self.instance_variable_set(:@counter, 0) unless self.instance_variable_defined?(:@counter)
      self.instance_variable_set(:@counter, self.instance_variable_get(:@counter)+1)
      return self.class.to_s + ' ' + self.instance_variable_get(:@counter).to_s + args.join(',')
    }

    Test::Redef.rd 'TestClass#test_method' => check_self  do |r|
      assert_equal( 'TestClass 1', a.test_method )
      assert_equal( 'TestClass 2foo,bar', a.test_method('foo', 'bar') )
      assert_equal( 'TestClass 1', b.test_method )
    end
  end

  def test_redef_with_block
    a = TestClass.new

    got = []
    a.test_method_with_block('1', '2') {|o,t| got << [o, t] }

    Test::Redef.rd(
      'TestClass#test_method_with_block' => proc {|one, two, &block|
        block.call(two, one)
      }
    ) do |r|
      a.test_method_with_block('1', '2') {|o,t| got << [o, t] }
    end

    a.test_method_with_block('1', '2') {|o,t| got << [o, t] }
    assert_equal( [['1', '2'], ['2', '1'], ['1', '2']], got )
  end

  def test_class_redef
    assert_equal( 'orig', TestClass.class_method )

    Test::Redef.rd 'TestClass.class_method' => lambda { 'new' } do |r|
      assert_equal( 'new', TestClass.class_method )
    end

    assert_equal( 'orig', TestClass.class_method )
  end

  def test_exception
    assert_equal( 'orig', TestClass.new.test_method )

    begin
      Test::Redef.rd 'TestClass#test_method' => lambda {|*args| 'new' } do |r|
        assert_equal( 'new', TestClass.new.test_method )
        raise ArgumentError
      end
    rescue ArgumentError
    end

    assert_equal( 'orig', TestClass.new.test_method )
  end

  def test_wiretap
    a = TestClass.new
    assert_equal( 'orig', a.test_method )

    Test::Redef.rd 'TestClass#test_method' => :wiretap do |rd|
      assert_equal( 'orig', a.test_method('foo') )
      assert_equal( [['foo']], rd.args )
      assert_equal( 1, rd.called )
      assert_equal( ['foo'], a.args )
    end

    Test::Redef.rd 'TestClass.class_method' => :wiretap do |rd|
      assert_equal( 'orig', TestClass.class_method('foo') )
      assert_equal( [['foo']], rd.args )
      assert_equal( 1, rd.called )
    end

    Test::Redef.rd 'TestClass#test_method_with_block' => :wiretap do |rd|
      args = []
      a.test_method_with_block(1, 2) do |p1, p2|
        args += [p1, p2]
      end

      assert_equal( [1, 2], args )
    end
  end

  def test_rd
    a = TestClass.new
    assert_equal( "orig", a.test_method )
    assert_equal( "orig2", a.test_second_method )
    Test::Redef.rd(
      "TestClass#test_method" => proc { |*args|
        "#{self.test_second_method} new1"
      },
      "TestClass#test_second_method" => proc { "new2" },
      "TestClass.class_method" => proc { "new3" },
    ) do |rd|
      assert_equal( "new2 new1", a.test_method("pacifies-empiricism\'s") )
      assert_equal( "new2", a.test_second_method )
      assert_equal( "new3", TestClass.class_method )

      assert_equal( 1, rd[:test_method].called )
      assert_equal( [["pacifies-empiricism\'s"]], rd[:test_method].args )
      assert_equal( [["pacifies-empiricism\'s"]], rd.args(:test_method) )

      assert_equal( 1, rd['TestClass#test_method'].called )
      assert_equal( [["pacifies-empiricism\'s"]], rd['TestClass#test_method'].args )

      assert_equal( 1, rd[:class_method].called )
      assert_equal( [[]], rd[:class_method].args )
    end
  end

  def test_class_vs_instance
    a = TestClass.new
    Test::Redef.rd(
      'TestClass#both_class_and_instance' => proc { 'new_instance' },
      'TestClass.both_class_and_instance' => proc { 'new_class' },
    ) do |rd|
      a = TestClass.new

      assert_equal( 0, rd['TestClass#both_class_and_instance'].called )
      assert_equal( 0, rd['TestClass.both_class_and_instance'].called )


      assert_equal( 'new_instance', a.both_class_and_instance )
      assert_equal( 'new_class', TestClass.both_class_and_instance )

      a.both_class_and_instance

      assert_equal( 2, rd['TestClass#both_class_and_instance'].called )
      assert_equal( 1, rd['TestClass.both_class_and_instance'].called )

      assert_raises( ArgumentError ) do
        rd.called
      end

      assert_raises( ArgumentError ) do
        rd[:both_class_and_instance].called
      end
    end
  end

  def test_redef_private_method
    a = TestClass.new
    assert_equal( 1, a.init_val )

    Test::Redef.rd(
      'TestClass#initialize' => proc { @init_val = 2 },
    ) do
      b = TestClass.new
      assert_equal( 2, b.init_val )
    end

    Test::Redef.rd 'TestClass#initialize' => proc { @init_val = 3 } do
      c = TestClass.new
      assert_equal( 3, c.init_val )
    end

    assert( TestClass.private_method_defined?('private_method') )
    Test::Redef.rd 'TestClass#private_method' => proc { 'new priv' } do
      c = TestClass.new
      assert_equal( 'new priv', c.call_private_method )
    end
    assert( TestClass.private_method_defined?('private_method') )
  end

  def test_empty_proc
    a = TestClass.new
    assert( a.test_method != nil )
    Test::Redef.rd "TestClass#test_method" => :empty do
      assert_nil( a.test_method )
    end
  end

  def test_publicize_method
    a = TestClass.new
    assert_raises( NoMethodError ) do
      a.private_method
    end
    Test::Redef.publicize_method(
      'TestClass#private_method',
      'TestClass.private_class_method',
      'TestClass#test_method',
      'TestClass.class_method',
    ) do
      assert_equal( 'orig private method', a.private_method )
      assert_equal( 'bolero-mute', TestClass.private_class_method )
      assert_equal( 'orig', a.test_method )
      assert_equal( 'orig', TestClass.class_method )
    end

    assert_raises( NoMethodError ) do
      a.private_method
    end

    # don't privatize methods that were public
    assert_equal( 'orig', a.test_method )
    assert_equal( 'orig', TestClass.class_method )
  end

  # this sometimes seems like a good idea, but can lead to subtle bugs
  # e.g. if you change a method name everywhere in code it is possible
  # that your test will still continue to work even though the assumptions
  # it is based on have changed
  def test_no_redefing_method_into_existance
    assert_raises( ArgumentError ) do
      Test::Redef.rd "TestClass#not_a_method" => :empty do
        assert_nil( a.test_method )
      end
    end
  end

  def test_arg_mutation
    Test::Redef.rd 'TestClass#test_method' => proc { 'new' } do |r|
      hash = {:coffinmaking => 'exospore'}
      hash_cpy = hash.clone

      TestClass.new.test_method(hash)
      assert_equal( [[hash_cpy]], r.args )

      hash.clear
      assert_equal( [[hash_cpy]], r.args )
    end
  end

  def test_rd_return_value
    ret = Test::Redef.rd('TestClass.class_method' => :empty) do
      'silundum-ultrasystematic'
    end
    assert_equal( 'silundum-ultrasystematic', ret )
  end

  def test_call_order
    Test::Redef.rd(
      'TestClass#test_method' => :empty,
      'TestClass#test_second_method' => :empty,
    ) do |rd|
      assert_equal( [], rd.call_order )

      TestClass.new.test_method
      TestClass.new.test_second_method
      assert_equal( ['TestClass#test_method', 'TestClass#test_second_method'], rd.call_order )

      rd.reset
      assert_equal( [], rd.call_order )
    end
  end

  def test_anonymous_class
    @naughty_class = Class.new do
      def self.class_method
        'boring_class_method'
      end

      def object_method
        'boring_object_method'
      end
    end

    naughty_obj = @naughty_class.new
    Test::Redef.rd(
      [@naughty_class, :class_method] => proc { 'exciting_class_method' },
      [naughty_obj, 'object_method'] => proc { 'exciting_object_method' },
    ) do |rd|
      assert_equal( 'exciting_class_method', @naughty_class.class_method )
      assert_equal( 'exciting_object_method', naughty_obj.object_method )

      assert_equal( 1, rd[:class_method].called )
      assert_equal( 1, rd[:object_method].called )
    end

    assert_equal( 'boring_class_method', @naughty_class.class_method )
    assert_equal( 'boring_object_method', naughty_obj.object_method )
  end

  def test_bad_method_name_checking
    Test::Redef.rd 'TestClass.class_method' => :wiretap do |rd|
      assert_equal( 0, rd[:class_method].called )
      assert_equal( [], rd[:class_method].args )

      assert_raises( ArgumentError ) do
        rd[:prebreathe_subradius].called
      end

      assert_raises( ArgumentError ) do
        rd[:prebreathe_subradius].args
      end

      assert_raises( ArgumentError ) do
        rd[:prebreathe_subradius].reset
      end
    end
  end
end

class TestClass
  attr_accessor :args
  attr_accessor :init_val

  def initialize
    @init_val = 1
  end

  def test_method(*args)
    @args = args
    return 'orig'
  end

  def test_second_method
    return 'orig2'
  end

  def test_method_with_block(one, two)
    yield(one, two)
  end

  def self.class_method(*args)
    return 'orig'
  end

  def both_class_and_instance
    return 'orig instance'
  end

  def self.both_class_and_instance
    return 'orig class'
  end

  def send
    return 'some module writer hates you'
  end

  def call_private_method
    return private_method
  end

  private
  def private_method
    return "orig private method"
  end

  def self.private_class_method
    return "bolero-mute"
  end
end
