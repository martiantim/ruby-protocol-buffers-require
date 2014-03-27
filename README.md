# ProtocolBuffersRequire

[![Build Status](https://travis-ci.org/peter-edge/ruby-protocol-buffers-require.png?branch=master)](https://travis-ci.org/peter-edge/ruby-protocol-buffers-require)

Compile and require protocol buffers at runtime with the ruby-protocol-buffers library.

https://github.com/codekitchen/ruby-protocol-buffers

## Example

Say you have the following layout:

lib/my_gem.rb  
ext/proto/one/one.proto  
ext/proto/two/two.proto

In my_gem.rb, you can do:

```ruby
require 'protocol_buffers_require'

base_path = File.expand_path(File.join(File.dirname(__FILE__)), "..", "ext", "proto")
ProtocolBuffers.require(
  File.join(base_path, "one"),
  File.join(base_path, "two")
)
```

And all protocol buffer definitions will be imported as if you compiled these separately
using ruby-protoc. Imports are allowed between files in different directories (all directories
are included using the equivalent of '-I').

Written for Locality  
http://www.locality.com

## Authors

Peter Edge  
peter@locality.com  
http://github.com/peter-edge

## License

MIT
