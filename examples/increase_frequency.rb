# A triangle wave that increases in frequency over 3 seconds
require_relative '../lib/easy_audio'

stream = EasyAudio.easy_open(freq: 220, &EasyAudio::Waveforms::TRIANGLE)

Thread.new { loop { stream.frequency += 50; sleep 0.2 } }
sleep 3
