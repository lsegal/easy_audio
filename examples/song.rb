require 'thread'
require_relative '../lib/easy_audio'

def freq_for_note(note)
  2.0 ** ((note-49.0)/12.0) * 440.0
end

class Sound
  def initialize(freq: 1, &block)
    @freq = freq
    @fn = block
    @frame = 0
    @step = 0
  end

  attr_accessor :frame, :step, :freq

  def next_frame(frame, step)
    @frame, @step = frame, step
    calculate_step
    instance_exec(&@fn)
  end

  def calculate_step
    @step = (step * @freq.to_f) % 1.0
  end

  def e(fn = nil, &block)
    instance_exec(&(fn || block))
  end

  def f(fn = nil, note, &block)
    orig_freq, orig_step = @freq, @step
    @freq = freq_for_note(note)
    calculate_step
    result = e(fn || block)
    @freq = orig_freq
    @step = orig_step
    result
  end

  def fr(fn = nil, freq, &block)
    orig_freq, orig_step = @freq, @step
    @freq = freq
    calculate_step
    result = e(fn || block)
    @freq = orig_freq
    @step = orig_step
    result
  end
end

class Sequencer
  def initialize(stream: EasyAudio::EasyStream.new(amp: 0.8, frame_size: 4096, latency: 12.0), bpm: 120)
    srand
    @mutex = Mutex.new
    @stream = stream
    @stream.fn = method(:next_frame)
    @scene = nil
    @scenes = {}
    @rendered_scenes = {}
    @keyframes = {}
    @tracks = []
    @bpm = bpm.to_f
    @sample = 0
    @kf = 0
    @samples_per_bar = (@stream.sample_rate * 60) / @bpm
    @stopped = false
  end

  def next_frame
    if @keyframes[@kf.to_i]
      @scene = @keyframes[@kf.to_i]
    end
    @kf += 1
    result = @rendered_scenes[@scene][@sample.to_i]
    @sample = (@sample + 1) % @samples_per_bar.to_i
    result
  end

  def add_scene(name = nil, tracks)
    @scenes[name.to_s || 'default'] = tracks.map do |track|
      track.map {|t| Sound === t ? t : t ? Sound.new(&t) : nil }
    end
  end

  def render_scenes
    @rendered_scenes = {}
    @keyframes.values.each do |name|
      @rendered_scenes[name] = @samples_per_bar.to_i.times.map do |i|
        @scenes[name].map do |track|
          q = @samples_per_bar.to_i / track.length
          n = (i / q).to_i
          step = (i.to_f / @stream.sample_rate) % 1.0
          track[n] ? track[n].next_frame(i % q, step) : 0.0
        end.reduce(&:+)
      end
    end
  end

  def play(scenes: ['16:default'])
    @stopped = false
    @sample = 0
    @kf = 0
    @keyframes = {}

    last_frame = 0
    scenes.each do |scene|
      bars, name = *scene.split(':')
      @keyframes[last_frame] = name.to_s
      last_frame += (bars.to_i * @samples_per_bar).to_i
    end

    puts "Rendering scenes..."
    render_scenes

    puts "Starting audio..."
    @stream.start
    sleep(last_frame.to_f / @stream.sample_rate)
    sleep 0.1 while @kf < last_frame
  end
end

def sn(fn, note)
  Sound.new(freq: freq_for_note(note), &fn)
end

# Instruments

SINE = -> { Math.sin(2 * Math::PI * step) * 0.8 }
SQUARE = -> { step < 0.5 ? -0.8 : 0.8 }
TRIANGLE = -> { (1 - 4 * (step.round - step).abs) * 0.8 }
SAW = -> { 2 * (step - step.round) * 0.8 }

NOISE = -> { rand - 0.5 }

EXP_FALLOFF  = -> { [(1 / (frame * 0.002)), 1.0].min }
EXP_FALLOFF2 = -> { [(1 / (frame * 0.005)), 1.0].min }
LIN_FALLOFF  = -> { (50000.0 - @frame) / 50000.0 }

SNARE = -> { e(EXP_FALLOFF) * e(NOISE) * 0.8 }
BASSDRUM = -> { e(EXP_FALLOFF2) * e(NOISE) * 0.1 + e(SINE) * 0.9 * e(EXP_FALLOFF) }


LEAD = -> { e(TRIANGLE) * e(EXP_FALLOFF) }
LEAD2 = -> { e(SAW) * Math.sin(step * 4.0) * 0.2 * fr(SINE,2*freq) * 0.5 + e(NOISE) * 0.2 }
SQUARELEAD = -> { e(SQUARE) * 0.4 * e(EXP_FALLOFF) }
SQUARELEAD2 = -> { e(SQUARE) * 0.4 * e(EXP_FALLOFF2) }
PHASED = -> { fr(SINE, Math.sin(@step / 4.0) * (freq / 2.0)) * 0.01 * [1.0,frame.to_f/50000.0].max }

# Sequencer and scenes

s = Sequencer.new bpm: 43
s.add_scene :A, [
  [nil, nil, SNARE, nil],
  [sn(BASSDRUM, 17), nil, nil, nil],
  [nil, sn(SQUARELEAD, 46)] * 4,
  [sn(LEAD, 51), nil, nil, sn(TRIANGLE,49)],
  [nil, sn(SINE,20), nil, nil] * 2,
]
s.add_scene :A2, [
  [nil, nil, SNARE, nil],
  [sn(BASSDRUM, 17), nil, nil, nil],
  [nil, sn(SQUARELEAD, 46)] * 4,
  [sn(LEAD, 51), nil, nil, sn(TRIANGLE,54)],
  [nil, sn(SINE,26), nil, nil] * 2,
]
s.add_scene :B, [
  [sn(-> { e(NOISE) * 0.3 * e(EXP_FALLOFF2) + e(SQUARE) * 0.1 * e(EXP_FALLOFF2) }, 70), nil, nil, nil] * 4,
  [nil, nil, SNARE, nil],
  [sn(BASSDRUM, 17), nil, nil, nil, SNARE, nil, sn(BASSDRUM, 17), nil],
  [nil, sn(SQUARELEAD, 42)] * 4,
  [sn(LEAD, 51), nil, nil, sn(TRIANGLE,49)],
  [nil, sn(SINE,23), nil, nil] * 2,
]
s.add_scene :C, [
  [sn(-> { e(NOISE) * 0.3 * e(EXP_FALLOFF2) + e(SQUARE) * 0.1 * e(EXP_FALLOFF2) }, 70), nil, nil, nil] * 4,
  [nil, nil, nil, nil, nil, SNARE, nil, nil, nil, nil],
  [nil, sn(SQUARELEAD, 49), nil, sn(SQUARELEAD, 49), nil, nil, nil, sn(-> { e(TRIANGLE) * 0.5 }, 54)],
  [sn(BASSDRUM, 17), nil, nil, nil, nil, nil, sn(BASSDRUM, 17), nil],
  [sn(LEAD, 46), sn(LEAD, 46), nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, sn(TRIANGLE,42)],
  [nil, nil, nil, nil, sn(LEAD2,59), sn(LEAD2,59), nil, nil],
  [sn(SINE,18)],
  [sn(PHASED,20)]
]
s.add_scene :D, [
  [nil, sn(SQUARELEAD, 46)] * 4,
  [sn(LEAD, 51), nil, nil, sn(TRIANGLE,49)],
]
s.add_scene :D2, [
  [nil, sn(SQUARELEAD, 46)] * 4,
  [sn(TRIANGLE, 51), nil, nil, sn(TRIANGLE,46)],
]
s.add_scene :D3, [
  [nil, sn(SQUARELEAD, 46)] * 4,
  [sn(TRIANGLE, 42), nil, nil, nil],
]
s.add_scene :D4, [
  [nil, sn(SQUARELEAD, 46)] * 4,
]

s.add_scene :D5, [
  [nil, sn(-> { e(SQUARELEAD) * e(EXP_FALLOFF2) }, 46)] * 4,
  [sn(-> { e(SQUARELEAD) * e(EXP_FALLOFF2) }, 46), nil, nil, nil, nil, nil, nil, nil]
]

# Play!
s.play scenes: %w(
  2:D5
  1:A 1:A2 2:B 4:C
  1:A 1:A2 2:B 4:C
  1:D 1:D2 1:D3 1:D4
)
