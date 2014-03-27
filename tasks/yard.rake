require 'yard'

YARD::Rake::YardocTask.new(:doc) do |t|
  version = ProtocolBuffersRequire::GEM_VERSION
  t.options = ["--title", "ProtocolBuffersRequire #{version}", "--files", "LICENSE"]
end
