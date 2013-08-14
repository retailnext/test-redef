# Test::Redef ![Build Status](https://secure.travis-ci.org/nearbuy/test-redef.png?branch=master)

Replace methods with test code, get feedback on how they are called
and put it all back together when your test is done.

## Examples

``` ruby
require 'test/unit'
require 'test/redef'

class Example < Test::Unit::TestCase
  def test_redef
    now = Time.at(1375654620).utc
    Test::Redef.rd(
      'Time.now' => proc { now },  # replace with the given proc
      'Time#sunday?' => :wiretap,  # instrument existing implementation
      'Kernel#raise' => :empty,    # replace with empty proc
    ) do |rd|
      assert( Time.now.sunday? )
      assert_nothing_raised { raise ArgumentError }

      assert_equal( [[ArgumentError]], rd[:raise].args )
      assert_equal( 1, rd[:sunday?].called )
      assert( rd[:now].called? )
    end
  end
end
```

## Class Methods

### rd

Takes a hash of methods to replace.  Values can either be a proc,
which will be called in place of the original function, or one of the
built-in replacements, `:wiretap` and `:empty`.  `:wiretap`
instruments the original implementation and `:emtpy` is an empty proc.

Yields a Test::Redef object.  Original methods are reinstalled when
the block exits.

### publicize_method

Takes a list of private methods to temporarilly make public.  Yields
and returns them to private when the block exits.

## Instance Methods

### call_order

Returns a list of all redef'd methods in the order in which they were
called.

### []

Takes a method name and returns an object that you can call the
inspection methods on.  A method name can be either the fully
qualified name of the method (`Time.now`) or just the method name
(`now`, `:now`) if unambiguous.

## Inspection Methods

You can either be called on the return value of Test::Redef#[] or on
the Test::Redef object itself, passing in a method name.

### called

The number of times a method has been called.

### called?

Boolean, has the method been called.

### args

Arguments passed in to the method at each call.

### object

Object the method was called on at each call.

### reset

Throw away all data collected so far.  #called? will return `false`
until the method is called again.

## Support

Please report issues at https://github.com/nearbuy/test-redef/issues

## See Also

* https://metacpan.org/module/Test::Resub
* https://metacpan.org/module/Test::Wiretap

## License

Copyright (c) 2013, Nearbuy Systems, Inc
All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
