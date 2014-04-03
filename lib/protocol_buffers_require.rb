# -*- encoding: utf-8 -*-

require 'protocol_buffers_require/version'

require 'protocol_buffers'
require 'protocol_buffers/compiler'
require 'protocol_buffers/compiler/file_descriptor_to_ruby'

require 'logger'
require 'tempfile'

module ProtocolBuffersRequire

  @@logger = Logger.new(STDOUT).tap { |logger| logger.level = Logger::INFO }
  @@logger_enabled = false

  def self.set_logger_enabled(logger_enabled)
    @@logger_enabled = logger_enabled
    nil
  end

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
    if @@logger_enabled
      # TODO(pedge): This is the command that is executed, but this is copied from ProtocolBuffers::Compiler.compile
      # This should not depend on the logic within this method
      @@logger.info("protoc #{include_dirs.map { |include_dir| "-I#{include_dir}" }.join(' ')} -o#{protocfile.path} #{filenames.join(' ')}")
    end
    ProtocolBuffers::Compiler.compile(protocfile.path, filenames, :include_dirs => include_dirs)
    descriptor_set = Google::Protobuf::FileDescriptorSet.parse(protocfile)
    protocfile.close(true)

    ruby_out = Dir.mktmpdir
    paths = descriptor_set.file.map do |file_descriptor|
      if _skip?(file_descriptor)
        if @@logger_enabled
          @@logger.info("Skipping #{file_descriptor.name}")
        end
        nil
      else
        fullpath = filenames[filenames.index{|path| path.include? file_descriptor.name}]
        path = File.join(ruby_out, File.dirname(fullpath), File.basename(file_descriptor.name, ".proto") + ".pb.rb")
        FileUtils.mkpath(File.dirname(path)) unless File.directory?(File.dirname(path))
        File.open(path, "wb") do |file|
          dumper = FileDescriptorToRuby.new(file_descriptor)
          if @@logger_enabled
            @@logger.info("Writing #{file_descriptor.name} to #{path}")
          end
          dumper.write(file)
        end
        path
      end
    end.compact

    paths.each do |path|
      require path
    end
  end

  # PRIVATE

  def self._skip?(file_descriptor)
    if file_descriptor.has_options?
      if file_descriptor.options.has_java_package? && file_descriptor.options.has_java_outer_classname?
        if file_descriptor.options.java_package == "com.google.protobuf" && file_descriptor.options.java_outer_classname == "DescriptorProtos"
          return true
        end
      end
    end
    return false
  end
end
