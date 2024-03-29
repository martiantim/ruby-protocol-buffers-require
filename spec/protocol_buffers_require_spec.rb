# -*- encoding: utf-8 -*-

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers_require'

describe ProtocolBuffersRequire do

  it "does basic operations" do
    base_path = File.expand_path(File.join(File.dirname(__FILE__), "ext/proto"))
    ProtocolBuffersRequire.require_dirs(
      base_path,
      File.join(base_path, "one"),
    )
    ProtocolBuffersRequire.require_dirs(
      base_path,
      File.join(base_path, "three"),
      File.join(base_path, "two"),
      File.join(base_path, "google", "protobuf")
    )

    one_foo = Centzy::One::Foo.new(:string_1 => "one")
    one_foo.string_1.should == "one"
    two_foo = Centzy::Two::Foo.new(:string_1 => "two")
    two_foo.string_1.should == "two"
    three_foo = Centzy::Three::Foo.new(:string_1 => "three")
    three_foo.string_1.should == "three"

    two_foo2 = Centzy::Two::Foo.new(
      :string_1 => "two",
      :centzy_one_foo_9 => one_foo
    )
    two_foo2.centzy_one_foo_9.string_1.should == "one"
    two_foo2.string_1.should == "two"

    three_foo2 = Centzy::Three::Foo.new(
      :string_1 => "three",
      :centzy_one_foo_9 => one_foo,
      :centzy_two_foo_10 => two_foo
    )
    three_foo2.centzy_one_foo_9.string_1.should == "one"
    three_foo2.centzy_two_foo_10.string_1.should == "two"
    three_foo2.string_1.should == "three"

    Centzy::One::ServiceOne.rpcs.map { |rpc| rpc.name.to_s }.should =~ ["one_one_one", "one_two_two" ]
    Centzy::Two::ServiceOne.rpcs.map { |rpc| rpc.name.to_s }.should =~ ["one_one_one", "one_two_two" ]
    Centzy::Three::ServiceOne.rpcs.map { |rpc| rpc.name.to_s }.should =~ ["one_one_one", "one_two_two" ]

    Centzy::One::Bat::BAT_ONE.should == 1
    Centzy::Two::Bat::BAT_ONE.should == 1
    Centzy::Three::Bat::BAT_ONE.should == 1
  end
end
