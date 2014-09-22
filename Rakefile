task :default => :install

task :install do
  have_portaudio = false
  print "Checking for portaudio..."
  begin
    require "ffi-portaudio"
    have_portaudio = true
    puts " yes."
  rescue LoadError
    puts "no."
  end

  if !have_portaudio
    success = false
    puts "Portaudio is missing, attempting to install..."

    if RbConfig::CONFIG['host_os'].match(/darwin/)
      puts "Detected Mac OS X, installing with Homebrew..."
      begin
        sh "brew install portaudio"
        success = true if $? == 0
      rescue
        puts "Could not install portaudio. Do you have Homebrew installed?"
      end
    else
      puts "Only OS X installation currently supported. Install portaudio " +
           "from http://portaudio.com and reinstall."
    end

    if success
      puts "Installed portaudio. Continuing installation of easy_audio..."
    end
  end
end
