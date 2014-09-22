# Play a one second sine wave at 440hz (A note)
require_relative '../lib/easy_audio'

EasyAudio.easy_open(&EasyAudio::Waveforms::SINE)
sleep 1
