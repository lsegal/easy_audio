# EasyAudio

EasyAudio is a simplified wrapper for the [portaudio][portaudio] library, which
allows to you play or record audio directly from your sound card.

## Installing

```sh
$ gem install easy_audio
```

Note: if you are on a Linux or Windows machine you will need to manually
install portaudio to a location in your library paths. The gem will attempt
to install this automatically on OS X through [Homebrew][brew].

## Usage

Here's how you can easily play a sine wave at 440hz:

```ruby
require 'easy_audio'

EasyAudio.easy_open(&EasyAudio::Waveforms::SINE)
sleep 2 # play for 2 seconds
```

Here's a triangle wave that increases its frequency over 3 seconds:

```ruby
require 'easy_audio'

stream = EasyAudio.easy_open(freq: 220, &EasyAudio::Waveforms::TRIANGLE)
Thread.new { loop { stream.frequency += 50; sleep 0.2 } }
sleep 3
```

Record audio from your microphone and play it back a second later:

```ruby
require 'easy_audio'

EasyAudio.easy_open(in: true, out: true, latency: 1.0) { current_sample }
sleep 10 # for 10 seconds
```

## Documentation

See the API documentation on [rubydoc.info][docs].

## License

EasyAudio is copyright &copy; 2014 by Loren Segal and licensed under the BSD
license. See the LICENSE file for more information.

[portaudio]: http://portaudio.com
[brew]: http://brew.sh
[docs]: http://rubydoc.info/gems/easy_audio/frames
