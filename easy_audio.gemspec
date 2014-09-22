Gem::Specification.new do |s|
  s.name          = "easy_audio"
  s.summary       = "EasyAudio is a simplified wrapper for the portaudio library."
  s.description   = "EasyAudio allows you to play or record from your sound card."
  s.version       = File.read("lib/easy_audio.rb")[/VERSION = "(.+?)"/, 1]
  s.author        = "Loren Segal"
  s.email         = "lsegal@soen.ca"
  s.homepage      = "http://github.com/lsegal/easy_audio"
  s.platform      = Gem::Platform::RUBY
  s.files         = `git ls-files`.split(/\s+/)
  s.extensions    = ["Rakefile"]
  s.license       = "BSD"

  s.add_runtime_dependency "ffi-portaudio", "~> 0.0"
end
