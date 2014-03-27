# -*- encoding: utf-8 -*-

require 'protocol_buffers_require/version'

require 'protocol_buffers'
require 'protocol_buffers/compiler'
require 'protocol_buffers/compiler/file_descriptor_to_ruby'

require 'tempfile'

module ProtocolBuffersRequire

  def self.require_dirs(*include_dirs)
    include_dirs = include_dirs.map do |include_dir|
      File.expand_path(include_dir)
    end
    filenames = include_dirs.map do |include_dir|
      Dir.glob(File.join(include_dir, "*.proto"))
    end.flatten.map do |file|
      File.expand_path(file)
    end

    protocfile = Tempfile.new("ruby-protoc")
    protocfile.binmode
    ProtocolBuffers::Compiler.compile(protocfile.path, filenames, :include_dirs => include_dirs)
    descriptor_set = Google::Protobuf::FileDescriptorSet.parse(protocfile)
    protocfile.close(true)

    ruby_out = Dir.mktmpdir
    paths = descriptor_set.file.map do |file_descriptor|
      fullpath = filenames[filenames.index{|path| path.include? file_descriptor.name}]
      path = File.join(ruby_out, File.dirname(fullpath), File.basename(file_descriptor.name, ".proto") + ".pb.rb")
      FileUtils.mkpath(File.dirname(path)) unless File.directory?(File.dirname(path))
      File.open(path, "wb") do |file|
        dumper = FileDescriptorToRuby.new(file_descriptor)
        dumper.write(file)
      end
      path
    end

    paths.each do |path|
      require path
    end
  end
end