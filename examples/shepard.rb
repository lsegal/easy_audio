require_relative '../lib/easy_audio'

def render(freq: 220.0, time: 1.0, sample_rate: 44100)
  (sample_rate * time).to_i.times.map do |n|
    4.times.to_a.map do |i|
      12.times.to_a.map do |j|
        fij = freq * 2 ** i * 2 ** (j / 12.0)
        a = Math.exp(-(Math.log2(fij / freq) ** 2) / 0.5)
        a * Math.sin(Math::PI * 2 * fij * n / sample_rate)
      end.to_a.reduce(&:+)
    end.to_a.reduce(&:+)
  end
end

puts "Rendering..."
buffer = render(time: 4)
puts "Playing..."
EasyAudio.easy_open { buffer.shift }
sleep 4
