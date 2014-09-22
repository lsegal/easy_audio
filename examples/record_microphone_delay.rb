# Record data from the microphone and
# play it back on output with a 1 second delay
require_relative '../lib/easy_audio'

EasyAudio.easy_open(in: true, out: true, latency: 1.0) { current_sample }
sleep 10 # for 10 seconds
