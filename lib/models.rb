require 'json'

# a uniform set of segments
class Sample

  def initialize(fn:, string: nil, header: nil)
    @segments = []
    if header
      check_header_line header
    elsif string # try to identify format
      case string
      when /^\w/ # assume tsv
        string.lines.map(&:chomp).each_with_index do |line, i|
          if i == 0
            check_header_line line
          else
            add_segment_from_line fn:, line:
          end
        end
      when /^\s*{/ # assume json
        add_object fn:, object: JSON.parse(string)
      else
        raise "unknown format"
      end
    end
  end

  def check_header_line(line)
    @header_array = check_header line
    if @header_array == :bad
      raise "bad header: #{line}"
    else
      @header_string = line
    end
  end

  # only /^file\tbeg\tend\ttext\speaker$/
  def check_header(header)
    case header
    when /^file\tbeg\tend\ttext\tspeaker$/
      header.split "\t"
    when "start\tend\ttext"
      @whisper = true
      @header_string = "file\t#{header}"
      @header_string.split "\t"
    else
      :bad
    end
  end

  # add while checking format
  def add_from_string(fn:, string:, headerless: false)
    string.lines.map(&:chomp).each_with_index do |line, i|
      if i == 0 and not headerless
        raise "bad header: #{line}" if line != @header_string
      else
        add_segment_from_line fn:, line:
      end
    end
  end

  def add_segment_from_line(fn:, line:)
    a = line.split "\t", -1
    if a.length != @header_array.length
      raise "bad line, #{a.length} columns: #{line.gsub "\t", "TAB"}"
    end
    segment = {}
    if @whisper
      segment[:file] = fn
    end
    @header_array.zip(a).each do |k, v|
      v = v.to_f / 60 if @whisper and (k == 'beg' or k == 'end')
      segment[k.to_sym] = v
    end
    @segments << segment
  end


  def norm(x)
    x.gsub(/[-=#,.?()]/, '').downcase
  end

  def add_object(fn:, object:)
    if object['monologues'] # rev
      @header_array = %w[ file beg end text speaker ]
      @header_string = @header_array.join "\t"
      # @header ||= %w[ file beg end text speaker ]
      object['monologues'].each do |m|
        speaker = m['speaker']
        m['elements'].each do |e|
          s = {}
          if e['type'] == 'text'
            s = {
              file: fn,
              beg: e['ts'],
              end: e['end_ts'],
              text: e['value'],
              speaker: speaker
            }
            @segments << s
          end
        end#.flatten.map { |x| norm x }
      end
    else
      raise "unknown format"
    end
  end

  def print
    puts @header_string
    puts @segments.map { |x| @header_array.map { |y| x[y.to_sym] }.join "\t" }
  end

end

