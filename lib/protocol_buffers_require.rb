# -*- encoding: utf-8 -*-

require 'protocol_buffers_require/version'

require 'protocol_buffers'
require 'protocol_buffers/compiler'
require 'protocol_buffers/compiler/file_descriptor_to_ruby'

require 'logger'
require 'tempfile'
require 'set'
require 'digest'

module ProtocolBuffersRequire

  @@logger = Logger.new(STDOUT).tap { |logger| logger.level = Logger::INFO }
  @@logger_enabled = false

  @@required_filenames = Set.new
  @@required_file_descriptor_md5s = Set.new

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
    # TODO(pedge): This is the command that is executed, but this is copied from ProtocolBuffers::Compiler.compile
    # This should not depend on the logic within this method
    _log("protoc #{include_dirs.map { |include_dir| "-I#{include_dir}" }.join(' ')} -o#{protocfile.path} #{filenames.join(' ')}")
    ProtocolBuffers::Compiler.compile(protocfile.path, filenames, :include_dirs => include_dirs)
    descriptor_set = Google::Protobuf::FileDescriptorSet.parse(protocfile)
    protocfile.close(true)

    file_descriptors = descriptor_set.file.reject do |file_descriptor|
      _skip_and_log?(file_descriptor)
    end

    #Use same directory if files haven't changed
    #TODO: Ideally don't run protoc or write the files if dir exists but that's kinda complicated based on how require works below
    filename_hash = Zlib.crc32(filenames.join(","))
    most_recent = filenames.map do |f|
      File.mtime(f)
    end.max
    ruby_out = "#{Dir.tmpdir}/proto-#{filename_hash}-#{most_recent.to_i}"
    Dir.mkdir(ruby_out) if !Dir.exists?(ruby_out)

    package_to_path = file_descriptors.inject(Hash.new) do |hash, file_descriptor|
      fullpath = filenames[filenames.index{|path| path.include? file_descriptor.name}]
      path = File.join(ruby_out, File.dirname(fullpath), File.basename(file_descriptor.name, ".proto") + ".pb.rb")
      FileUtils.mkpath(File.dirname(path)) unless File.directory?(File.dirname(path))
      File.open(path, "wb") do |file|
        dumper = FileDescriptorToRuby.new(file_descriptor)
        _log("Writing #{file_descriptor.name} with package #{file_descriptor.package} to #{path}")
        dumper.write(file)
      end
      hash[file_descriptor.package] = path
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

  def self._skip_and_log?(file_descriptor)
    skip = _skip?(file_descriptor)
    _log("Skipping #{file_descriptor.name} with package #{file_descriptor.package}") if skip
    skip
  end

  def self._skip?(file_descriptor)
    md5 = Digest::MD5.new.digest(file_descriptor.serialize_to_string)
    if @@required_file_descriptor_md5s.include?(md5)
      return true
    else
      @@required_file_descriptor_md5s << md5
    end

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

  def self._log(string)
    if @@logger_enabled
      @@logger.info(string)
    end
  end

  def self._package_to_base_module_and_module_name(package)
    modules = package.split('.').map { |sub_package| _camelize(sub_package).to_sym }
    return modules.size == 1 ? :Object : modules[0..-2].join('::'), modules.last
  end

  def self._camelize(string)
    string.to_s.gsub(/(?:^|_)(.)/) { $1.upcase }
  end
end
