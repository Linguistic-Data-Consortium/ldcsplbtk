require 'json'

# a uniform set of segments
class Sample

  attr_accessor :header_array, :segments, :durations

  def initialize
    @segments = []
  end

  def set_header(x)
    @header_array = x
    @header_string = @header_array.join "\t"
  end

  def init_from(string:, fn: nil)
    @fn = fn
    raise "already initialized" if @segments.length > 0
    @header = false
    case string
    when /^\S+ 1 / # assume ctm
      # @format = :ctm
      set_header %w[ file beg end text ]
      lines = string.lines.map(&:chomp)
      lines.each do |line|
        add_segment_from_ctm line:
      end
    when /^\w/ # assume tsv
      # @format = :tsv
      lines = string.lines.map(&:chomp)
      check_header lines.first
      add_segment_from_tsv line: lines.first if !@header
      lines[1..-1].each do |line|
        add_segment_from_tsv line: line
      end
    when /^\s*{/ # assume json
      add_object object: JSON.parse(string)
    else
      raise "unknown format"
    end
    self
  end

  def timestamp(x)
    x =~ /^\d+\.\d+\z/
  end

  def check_header(line)
    case line
    when /^file\tbeg\tend\ttext(\tspeaker(\tsection)?)?\z/
      # @header_string = header
      # @header_string.split "\t"
      @header_string = line
      @header = true
      @header_array = @header_string.split "\t"
    when "start\tend\ttext"
      raise "the file name must be set" if @fn.nil?
      # @format = :whisper
      @header = true
      set_header %w[ file beg end text ]
    else
      @header = false
      a = line.split("\t", -1)
      case a.length
      when 3
        if timestamp(a[0]) and timestamp(a[1]) and a[2] =~ /^(non-)?(speech)\z/
          @sad = true
          @header_array = %w[ file beg end text ]
        else
          raise "bad header: #{line}"
        end
      when 4, 5, 6
        if timestamp(a[1]) and timestamp(a[2])
          @header_array = %w[ file beg end text ]
          @header_array << 'speaker' if a.length > 4
          @header_array << 'section' if a.length > 5
        else
          raise "bad header: #{line}"
        end
        @header_string = @header_array.join "\t"
      else
        raise "bad header: #{line}"
      end
    end
  end

  def add(other_sample:)
    if @header_array
      raise "headers don't match" if other_sample.header_array != @header_array
    else
      @header_array = other_sample.header_array
      @header_string = @header_array.join "\t"
    end
    other_sample.segments.each do |x|
      @segments << x
    end
  end

  # # add while checking format
  # def add_from_string(fn:, string:)
  #   case @format
  #   when :rev, :google, :ibm, :azure
  #     add_object fn:, object: JSON.parse(string)
  #   else
  #     string.lines.map(&:chomp).each_with_index do |line, i|
  #       if @header and i == 0
  #         raise "bad header: #{line}" if line != @header_string
  #       else
  #         add_segment_from_line fn:, line:
  #       end
  #     end
  #   end
  # end

  def add_segment_from_ctm(line:)
    a = line.split
    a = [ a[0], a[2], a[3], a[4] ]
    if a.length != @header_array.length
      raise "bad line, #{a.length} columns: #{line.gsub "\t", "TAB"}"
    end
    segment = {}
    @header_array.zip(a).each do |k, v|
      case k
      when 'beg', 'end'
        v = v.to_f
      end
      segment[k.to_sym] = v
    end
    segment[:end] += segment[:beg]
    @segments << segment
  end

  # assumes the line matches the header
  # checks the number of fields, but that's it
  def add_segment_from_tsv(line:)
    a = line.split "\t", -1
    # a.unshift @fn if @format == :whisper or @sad
    if a.length != @header_array.length
      raise "bad line, #{a.length} columns: #{line.gsub "\t", "TAB"}"
    end
    segment = {}
    @header_array.zip(a).each do |k, v|
      case k
      when 'beg', 'end'
        v = v.to_f
        # v /= 1000 if @format == :whisper
      end
      segment[k.to_sym] = v
    end
    @segments << segment
  end

  def norm(x)
    x.gsub(/[-=#,.?()]/, '').gsub(/  +/, ' ').downcase
  end

  def add_object(object:)
    if object['monologues'] # assume rev
      # @format = :rev
      raise "the file name must be set" if @fn.nil?
      set_header %w[ file beg end text speaker ]
      # @header ||= %w[ file beg end text speaker ]
      object['monologues'].each do |m|
        speaker = m['speaker']
        m['elements'].each do |e|
          s = {}
          if e['type'] == 'text'
            s = {
              file: @fn,
              beg: e['ts'],
              end: e['end_ts'],
              text: e['value'],
              speaker: speaker
            }
            @segments << s
          end
        end#.flatten.map { |x| norm x }
      end
    elsif object['audio_metrics'] # ibm, but only because I requested audio metrics
      # @format = :ibm
      raise "the file name must be set" if @fn.nil?
      set_header %w[ file beg end text speaker ]
      object['results'].each do |x|
        x['alternatives'].first['timestamps'].each do |x|
          next if x[0][0] == '%'
          sp = ibmsp object['speaker_labels'], x[1], x[2]
          s = {
            file: @fn,
            beg: x[1],
            end: x[2],
            text: x[0],
            speaker: sp
          }
          @segments << s
        end
      end
    elsif object['results'] # assume google cloud
      a = object['results'].last['alternatives']
      if a.first.keys.length == 3
        raise "unknown format; might be google cloud without speaker tags"
      end
      # @format = :google
      raise "the file name must be set" if @fn.nil?
      set_header %w[ file beg end text speaker ]
      # @header ||= %w[ file beg end text speaker ]
      a.first['words'].each do |w|
        s = {}
        if true #e['type'] == 'text'
          s = {
            file: @fn,
            beg: gcts(w['startTime']),
            end: gcts(w['endTime']),
            text: w['word'],
            speaker: w['speakerTag'] # what about speakerLabel?
          }
          @segments << s
        end
      end
    elsif object['source'] # assume azure
      raise "the file name must be set" if @fn.nil?
      # @format = :azure
      set_header %w[ file beg end text speaker ]
      object['recognizedPhrases'].each do |x|
        raise "what to do?" if x['nBest'].count != 1
        sp = x['speaker'].to_s
        x['nBest'].first['words'].each do |x|
          s = {
            file: @fn,
            beg: (x['offsetMilliseconds'].to_f / 1000).round(3),
            end: 0,
            text: x['word'],
            speaker: sp
          }
          s[:end] = (s[:beg] + (x['durationMilliseconds'].to_f / 1000)).round(3)
          @segments << s
        end
      end
    elsif object['segments'] # assume whisper
      # @format = :whisper
      raise "the file name must be set" if @fn.nil?
      set_header %w[ file beg end text ]
      # @header ||= %w[ file beg end text speaker ]
      object['segments'].each do |m|
        m['words'].each do |e|
          s = {
            file: @fn,
            beg: e['start'],
            end: e['end'],
            text: e['word'].gsub(/\s/, '')
          }
          @segments << s
        end
      end
    elsif object['transcription'] # assume whisper.cpp
      # @format = :whispercpp
      raise "the file name must be set" if @fn.nil?
      set_header %w[ file beg end text ]
      # @header ||= %w[ file beg end text speaker ]
      last = object['transcription'][0]['offsets']['from']
      object['transcription'].each do |m|
        next if m['text'].length == 0
        # puts e['text']
        bb = (m['offsets']['from'].to_f / 1000).round(3)
        ee = (m['offsets']['to'].to_f / 1000).round(3)
        tt = m['text'].gsub(/\s|"/, '')
        s = {
          file: @fn,
          beg: bb,
          end: ee,
          text: tt
        }
        @segments << s
      end
    elsif object['pred_text']
      fn = object['audio_filepath']
      last = `soxi -D /clinical/poetry/#{fn}`
      set_header %w[ file beg end text ]
      s = {
        file: File.basename(fn, '.wav'),
        beg: 0.0,
        end: last.to_f,
        text: object['pred_text']
      }
      @segments << s
    # elsif object['transcription'] # assume whisper.cpp
    #   @format = :whispercpp
    #   raise "the file name must be set" if @fn.nil?
    #   @header_array = %w[ file beg end text ]
    #   @header_string = @header_array.join "\t"
    #   # @header ||= %w[ file beg end text speaker ]
    #   last = object['transcription'][0]['offsets']['from']
    #   object['transcription'].each do |m|
    #     if m['tokens'][0]['offsets']['from'] == 0
    #       last = m['offsets']['from']
    #     end
    #     bbb = last
    #     m['tokens'].each do |e|
    #       # next if e['text'] =~ /\[/
    #       # puts e['text']
    #       bb = ((bbb+e['offsets']['from']).to_f / 1000).round(3)
    #       ee = ((bbb+e['offsets']['to']).to_f / 1000).round(3)
    #       tt = e['text'].gsub(/\s|"/, '')
    #       case e['text'][0]
    #       when ' '
    #         s = {
    #           file: @fn,
    #           beg: bb,
    #           end: ee,
    #           text: tt
    #         }
    #         @segments << s
    #       when /\w|'/
    #         @segments[-1][:text] << tt
    #         @segments[-1][:end] = ee
    #       end
    #     end
    #   end
    else
      raise "unknown format"
    end
  end

  def ibmsp(x, b, e)
    # brute force! fix it someday
    a = x.select { |y| b >= y['from'] and e <= y['to'] }
    if a.count != 1
      raise "what to do?"
    end
    a.first['speaker'].to_s
  end

  def gcts(x)
    x['nanos'].to_f / 1_000_000_000 + x['seconds'].to_f
  end

  def print_prep(norm: false, after_time: nil, after_time_with_map: nil)
    @segments.each do |x|
      x[:file] = x[:file].sub(/^.+\//, '').sub /\.\w+$/, ''
      x[:text] = norm x[:text] if norm
    end
    # @header_string = @header_array.join "\t" if @format == :whisper
    puts @header_string
    if after_time
      @segments.select { |x| x[:end] > after_time }
    elsif after_time_with_map
      @segments.select { |x| x[:end] > after_time_with_map[x[:file]] }
    else
      @segments
    end
  end

  def print(norm: false, after_time: nil, after_time_with_map: nil)
    segments = print_prep(norm: false, after_time: nil, after_time_with_map: nil)
    #puts @segments.first[:end]
    #puts after_time_with_map[@segments.first[:file]]
    puts segments.map { |x| segment2line x }
  end

  def printone(norm: false, after_time: nil, after_time_with_map: nil)
    segments = print_prep(norm: false, after_time: nil, after_time_with_map: nil)
    segment = segments[0].dup
    segments[1..-1].each do |x|
      if x[:file] != segment[:file]
        puts segment2line segment
        segment = x.dup
      else
        segment[:end] = x[:end]
        segment[:text] += ' ' + x[:text]
      end
    end
    puts segment2line segment
  end

  def segment2line(segment)
    @header_array.map { |x| segment[x.to_sym] }.join "\t"
  end

  def print_only_these(map:)
    puts @header_string
    a = []
    segments.each do |x|
      speaker = map[x[:file]]
      if speaker
        a << x.dup
        # a[-1][:speaker] = speaker
      end
    end
    puts a.map { |x| segment2line x }
  end

  def fix_parens(x)
    x = x.gsub('(())', 'x')
    .gsub(/{\w+}/,'')
    .gsub(/[-=#()?!.,\/$%+~{}\[\]]/, '')
    # .gsub(/\d/, 'N')
    encoding_options = {
      :invalid           => :replace,  # Replace invalid byte sequences
      :undef             => :replace,  # Replace anything not defined in ASCII
      :replace           => '',        # Use a blank for those replacements
      :universal_newline => true       # Always break lines with \n
    }
    # x = 'x' if x.length == 0    
    x#.encode('ASCII', replace: '')
  end

  def stm
    @segments.map do |x|
      [
        x[:file],
        'A',
        x[:speaker],
        # 'spk',
        # file2spk(x[:file]),
        x[:beg],
        x[:end],
        fix_parens(x[:text])
      ].join ' '
    end.join("\n") + "\n"
  end

  def ctm
    @segments.map do |x|
      words = x[:text].split
      dur = ((x[:end] - x[:beg]) / words.length).round(3)
      beg = x[:beg]
      words.map.with_index do |y, i|
        beg += dur if i > 0
        [
          x[:file],
          'A',
          beg.round(3),
          dur,
          fix_parens(y)
        ].join ' '
      end
    end.flatten.join("\n") + "\n"
  end

  def change_speakers(speaker:)
    map = {}
    spk = nil
    puts segments.map { |x|
      y = x.dup
      y[:speaker] = if speaker == 'x'
        spk = '`' unless map[y[:file]]
        map[y[:file]] ||= {}
        map[y[:file]][y[:speaker]] ||= spk.succ!.dup
      else
        speaker
      end
      segment2line y
    }
  end

  def normalize_speakers
    map = {}
    spk = nil
    segments.map { |x|
      y = x.dup
      spk = '`' unless map[y[:file]]
      map[y[:file]] ||= {}
      map[y[:file]][y[:speaker]] ||= spk.succ!.dup
      y[:speaker] = map[y[:file]][y[:speaker]]
      segment2line y
    }
  end

  def print_find
    map = {}
    @segments.each do |x|
      map[x[:file]] ||= []
      map[x[:file]] << [ x[:beg], x[:end] ]
    end
    map.each do |k, v|
      puts "#{k} #{v.flatten.join(',')}"
    end
  end

  def print_findx
    s = nil
    t = 0
    # nt = 0
    offset = durations[@segments[0][:file]] / 2
    @segments.each_with_index do |x, i|
      b, e = x[:beg], x[:end]
      if x[:text] == 'speech' and b >= offset
        s ||= (b + @segments[i-1][:end]) / 2
        t += e - b
        # nt += b - @segments[i-1][:end]
        if t >= 60 * 5
          action1(s, e, i)
          break
        end
      end
    end
  end

  def action1(s, e, i)
    pad = (@segments[i+1][:beg] - e) / 2
    ee = (e + pad) - s
    # c = "sox #{@iwav} #{@owav} trim #{@s.round(2)} #{ee.round(2)}"
    # puts c
    #`#{c}`
    puts "#@fn #{ee.round(2)}"
  end

  def speakersx
    s = {}
    @segments.each do |x|
      s[x[:file]] ||= {}
      s[x[:file]][x[:speaker]] ||= 0
      s[x[:file]][x[:speaker]] += 1
    end
    puts s.to_a.map { |k, v|
     [ v.count, k ]
    }.sort_by { |x|
      x[0]
    }.map { |x|
      x.join ' '
    }.reverse
  end

  def rttm(dn)
    raise "#{dn} is not a directory" unless File.directory? dn
    files = {}
    @segments.each do |x|
      files[x[:file]] ||= {}
      files[x[:file]][x[:speaker]] ||= []
      files[x[:file]][x[:speaker]] << x
    end
    files.each do |fn, speakers|
      # puts "#{fn} #{speakers.count}"
      # next
      next if speakers.size == 0
      open("#{dn}/#{fn}.rttm", 'w') do |f|
        string = speakers.map do |speaker, segments|
          segments.map do |x|
            d = x[:end] - x[:beg]
            d = 0.001 if d == 0
            [
              'SPEAKER',
              fn,
              1,
              x[:beg],
              d,
              '<NA>',
              '<NA>',
              x[:speaker],
              '<NA>',
              '<NA>'
            ].join ' '
          end
        end.flatten.join "\n"
        f.puts string
      end
    end.compact
  end

  def text_only
    files = {}
    @segments.each do |x|
      files[x[:file]] ||= []
      files[x[:file]] << x[:text]
    end
    files.map do |fn, text|
      a = text.map do |token|
        # puts token if token =~ /^\d/
        # next
        case token
        when /rrrrrrrrrr+/
          token.sub /r+/, 'rrr'
        when /(\w+)\',?\z/
          $1
        # when /^[a-z\d]\w+\z/
        #   'a'
        when '120'
          'one hundred twenty'
        when '10'
          'ten'
        when '20'
          'twenty'
        when '15'
          'fifteen'
        when '1974'
          'nineteen seventy four'
        when /^(\d+).*\z/
          num $1
        when /^\$\d+(.\d\d)?\z/
          num(token) + ' dollars'
        else
          token
        end
      end
      [ fn, a.join(' ') ]
    end
  end


  def num(token)
    token.split(//).map do |x|
      case x
      when '0'
        'zero'
      when '1'
        'one'
      when '2'
        'two'
      when '3'
        'three'
      when '4'
        'four'
      when '5'
        'five'
      when '6'
        'six'
      when '7'
        'seven'
      when '8'
        'eight'
      when '9'
        'nine'
      end
    end.join ' '
  end

  def sum
    sums = {}
    slices = {}
    @segments.each do |x|
      sums[x[:file]] ||= 0
      sums[x[:file]] += x[:end] - x[:beg]
      slices[x[:file]] ||= []
      b = (x[:beg] * 1000).to_i
      e = (x[:end] * 1000).to_i
      slices[x[:file]] << (b...e).to_a
    end
    sums.each do |k, v|
      s = (slices[k].flatten.uniq.count.to_f / 1000).round(3)
      d = `soxi -D /clinical/poetry/penn_sound_audio/data/#{k}.flac`.chomp.to_f.round(3)
      puts "#{k} #{v.round(3)} #{s} #{d}"
    end
  end

  def sumx
    files = {}
    @segments.each do |x|
      files[x[:file]] ||= []
      # files[x[:file]] << x[:end] - x[:beg]
      b = (x[:beg] * 1000).to_i
      e = (x[:end] * 1000).to_i
      puts (x[:end]-x[:beg])
      puts (b...e).to_a.uniq.count
      exit
    end
    files.each do |k, v|
      puts "#{v.round(3)} #{k}"
    end
  end


  def init_from_arg
    raise "bad args" if ARGV.length != 1
    fn = ARGV[0]
    string = File.read fn
    init_from(string:)
  end

  def get_files
    @segments.map { |x| x[:file] }.uniq.sort
  end

  def split(dn)
    raise "#{dn} is not a directory" unless File.directory? dn
    files = {}
    @segments.each do |x|
      files[x[:file]] ||= []
      files[x[:file]] << x
    end
    files.each do |k, v|
      open("#{dn}/#{k}.tsv", 'w') do |f|
        f.puts @header_string
        f.puts v.map { |x| segment2line x }
      end
    end
  end

end

