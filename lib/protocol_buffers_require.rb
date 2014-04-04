# -*- encoding: utf-8 -*-

require 'protocol_buffers_require/version'

require 'protocol_buffers'
require 'protocol_buffers/compiler'
require 'protocol_buffers/compiler/file_descriptor_to_ruby'

require 'logger'
require 'tempfile'
require 'set'

module ProtocolBuffersRequire

  @@logger = Logger.new(STDOUT).tap { |logger| logger.level = Logger::INFO }
  @@logger_enabled = false

  @@required_filenames = Set.new

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
    end.reject do |filename|
      @@required_filenames.include?(filename)
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
    packages = Set.new
    package_to_path = descriptor_set.file.inject(Hash.new) do |hash, file_descriptor|
      if (!file_descriptor.has_package? || packages.include?(file_descriptor.package))
        raise ArgumentError.new("All files must have a unique package, non-unique was #{file_descriptor.package}")
      else
        packages << file_descriptor.package
      end
      if _skip?(file_descriptor)
        if @@logger_enabled
          @@logger.info("Skipping #{file_descriptor.name}")
        end
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
        hash[file_descriptor.package] = path
      end
      hash
    end

    # TODO(pedge): extra hacky
    while !package_to_path.empty?
      unrequired_package_to_path = Hash.new
      package_to_path.each do |package, path|
        begin
          require path
        rescue StandardError
          base_module, module_name = _package_to_base_module_and_module_name(package)
          eval(base_module).send(:remove_const, module_name) if eval(base_module).const_defined?(module_name)
          unrequired_package_to_path[package] = path
        end
      end
      package_to_path = unrequired_package_to_path
    end

    filenames.each do |filename|
      @@required_filenames << filename
    end
    nil
  end

  # PRIVATE

  def self._skip?(file_descriptor)
    # TODO(pedge): A better way to identify already required packages
    if file_descriptor.has_options?
      if file_descriptor.options.has_java_package? && file_descriptor.options.has_java_outer_classname?
        if file_descriptor.options.java_package == "com.google.protobuf" && file_descriptor.options.java_outer_classname == "DescriptorProtos"
          return true
        end
      end
    end
    return false
  end

  def self._package_to_base_module_and_module_name(package)
    modules = package.split('.').map { |sub_package| _camelize(sub_package).to_sym }
    return modules.size == 1 ? :Object : modules[0..-2].join('::'), modules.last
  end

  def self._camelize(string)
    string.to_s.gsub(/(?:^|_)(.)/) { $1.upcase }
  end
end
