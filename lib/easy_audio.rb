require 'ffi-portaudio'

# Easy Audio is a library to simplify the Portaudio interface
# @see http://portaudio.com
module EasyAudio
  VERSION = "0.1.0"

  # Represents a single buffer passed to the {Stream} process block
  class StreamPacket < Struct.new(:samples, :num_samples, :time_info, :status_info, :user_data)
  end

  # Represents a single audio input/output stream. See {#initialize} for usage
  # examples.
  class Stream < FFI::PortAudio::Stream
    include FFI::PortAudio

    # @!method start
    #   Starts processing the stream.

    # @!method stop
    #   Stops processing the stream.

    # Creates a new stream for processing audio. Call {#start} to start
    # processing.
    #
    # @option opts :sample_rate [Fixnum] (44100) the sample rate to play at.
    # @option opts :frame_size [Fixnum] (256) the number of frames per buffer.
    # @option opts :in [Boolean] whether to use the default input device.
    # @option opts :out [Boolean] whether to use the default output device.
    # @option opts :in_chans [Fixnum] (2) the number of channels to process from
    #   the input device.
    # @option opts :out_chans [Fixnum] (2) the number of channels to process
    #   from the output device.
    # @option opts :latency [Float] (0.0) the default latency for processing.
    # @yield [buffer] runs the provided block against the sample buffer data
    # @yieldparam buffer [StreamPacket] the sample data to process
    # @yieldreturn [Array<Float>] return an array of interlaced floating points
    #   for each channel in {#output_channels}.
    # @example Process audio from input (microphone) and playback on output
    #   EasyAudio::Stream.new(in: true, out: true) do |buffer|
    #     buffer.samples # echos the stream to output
    #   end
    # @see #start
    def initialize(opts = {}, &block)
      pa_start

      @fn = block
      @sample_rate = opts[:sample_rate] || 44100
      @frame_size = opts[:frame_size] || 256
      @input_channels = opts[:in_chans] || 1
      @output_channels = opts[:out_chans] || 1
      @latency = opts[:latency] || 0.01

      input, output = nil, nil
      if opts[:in] || opts[:in_chans]
        device = API.Pa_GetDefaultInputDevice
        input = stream_for(device, @input_channels, @latency)
      end

      if opts[:out] || opts[:out_chans] || !input
        device = API.Pa_GetDefaultOutputDevice
        output = stream_for(device, @output_channels, @latency)
      end

      open(input, output, @sample_rate, @frame_size)
    end

    attr_accessor :fn, :sample_rate, :frame_size
    attr_reader :input_channels, :output_channels, :latency

    private

    # Don't override this function. Pass in a `process` Proc object to
    # {#initialize} instead.
    def process(input, output, frames, time_info, status, user_data)
      result = run_process(input, output, frames, time_info, status, user_data)
      unless Array === result
        result = Array.new(frames * @output_channels).map {0}
      end

      output.write_array_of_float(result)
      :paContinue
    rescue => e
      puts e.message + "\n  " + e.backtrace.join("\n  ")
      :paAbort
    end

    def run_process(input, output, frames, time_info, status, user_data)
      inbuf = nil
      if input.address != 0
        inbuf = input.read_array_of_float(frames * @input_channels)
      end

      buffer = StreamPacket.new(inbuf, frames, time_info, status, user_data)
      @fn ? @fn.call(buffer) : nil
    end

    def stream_for(device, channels, latency)
      API::PaStreamParameters.new.tap do |stream|
        info = API.Pa_GetDeviceInfo(device)
        stream[:device] = device
        stream[:suggestedLatency] = latency
        stream[:hostApiSpecificStreamInfo] = nil
        stream[:channelCount] = channels
        stream[:sampleFormat] = API::Float32
      end
    end

    def pa_start
      return if @@stream_started
      API.Pa_Initialize
      at_exit { API.Pa_Terminate }
      @@stream_started = true
    end

    @@stream_started = false
  end

  # A simplified {Stream} class whose processor block only processes a single
  # frame at a time. See {Waveforms} for a set of pre-fabricated EasyStream
  # processor blocks for examples of how to process a single stream.
  #
  # Note that instead of passing state information as an argument to the block,
  # state is instead stored in the class itself, and the block is instance
  # evaluated. This makes it a bit slower to process, but much more convenient
  # for creating blocks.
  #
  # See {#initialize} for usage examples.
  class EasyStream < Stream

    # {include:Stream#initialize}
    #
    # @option (see Stream#initialize)
    # @option opts :freq [Float] (440.0) the frequency to generate {#step}
    #   values at.
    # @option opts :amp [Float] (1.0) the amplitude to scale values to.
    # @yield a process block that processes one frame at a time.
    # @yieldreturn [Array<Float>] return an array of interlaced floating points
    #   for each channel in {#output_channels}.
    # @example Process audio from input (microphone) and playback on output
    #   EasyAudio::EasyStream.new(in: true, out: true) { current_sample }.start
    # @example Play a sine wave.
    #   EasyAudio::EasyStream.new(&EasyAudio::Waveforms::SINE).start
    # @example Play a square wave.
    #   EasyAudio::EasyStream.new(&EasyAudio::Waveforms::SQUARE).start
    def initialize(opts = {}, &block)
      @frequency = opts[:freq] || 440.0
      @amp = opts[:amp] || 1.0
      @frame = 0
      @channel = 0

      super(opts, &block)
    end

    attr_accessor :amp, :frequency, :frame
    attr_reader :step, :channel, :samples, :num_frames
    attr_reader :time_info, :status_info, :user_data, :i, :current_sample

    private

    def run_process(input, output, frames, time_info, status, user_data)
      @samples = nil
      if input.address != 0
        @samples = input.read_array_of_float(frames * @input_channels)
      end

      @current_sample = nil
      @num_frames = frames
      @time_info = time_info
      @status_info = status
      @user_data = user_data

      result = Array.new(frames * @output_channels)
      if @fn
        @i = 0
        frames.times do
          @step = @frame * (@frequency / @sample_rate.to_f) % 1.0
          @output_channels.times do |ch|
            @channel = ch
            @current_sample = @samples[@i] if @samples
            result[@i] = @amp.to_f * (instance_exec(&@fn) || 0.0)
            @i += 1
          end
          @frame = (@frame + 1) % 1000000
        end
      else
        result = result.map {0}
      end

      result
    end
  end

  module_function

  # Quickly opens a {Stream} and calls {Stream#start}.
  #
  # @option (see Stream#initialize)
  # @yield (see Stream#initialize)
  # @yieldparam (see Stream#initialize)
  # @yieldreturn (see Stream#initialize)
  def open(opts = {}, &block)
    Stream.new(opts, &block).tap {|s| s.start }
  end

  # Quickly opens an {EasyStream} and calls {Stream#start}.
  #
  # @option (see EasyStream#initialize)
  # @yield (see EasyStream#initialize)
  # @yieldreturn (see EasyStream#initialize)
  # @example Process audio from input (microphone) and playback on output
  #   EasyAudio.easy_open(in: true, out: true) { current_sample }
  # @example Play a sine wave.
  #   EasyAudio.easy_open(&EasyAudio::Waveforms::SINE)
  # @example Play a square wave.
  #   EasyAudio.easy_open(&EasyAudio::Waveforms::SQUARE)
  # @see EasyStream#initialize
  def easy_open(opts = {}, &block)
    EasyStream.new(opts, &block).tap {|s| s.start }
  end

  # A collection of pre-fabricated waveforms that can be plugged into
  # {EasyStream} or {easy_open}.
  module Waveforms
    # Generates a sine wave
    SINE = -> { Math.sin(2 * Math::PI * step) }

    # Generates a square wave
    SQUARE = -> { step < 0.5 ? -1 : 1 }

    # Generates a triangle wave
    TRIANGLE = -> { 1 - 4 * (step.round - step).abs }

    # Generates a sawtooth wave
    SAW = -> { 2 * (step - step.round) }
  end
end
