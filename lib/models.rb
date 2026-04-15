require 'json'

# Represents a collection of speech transcript segments with uniform schema.
#
# Supports parsing multiple input formats:
# - TSV (tab-separated values) with various column configurations
# - CTM (NIST Conversation Time Marked format)
# - JSON formats from major ASR vendors:
#   - Rev.ai, Whisper, Whisper.cpp
#   - Google Cloud Speech-to-Text (v1 and v2)
#   - IBM Watson Speech-to-Text
#   - Microsoft Azure Speech Services
#
# All formats are normalized to a consistent internal representation with
# fields: file, beg (begin time), end (end time), text, and optionally
# speaker and section.
#
# Example:
#   sample = Sample.new
#   sample.init_from(string: File.read('transcript.tsv'))
#   sample.print  # Output as TSV
#   puts sample.stm  # Convert to STM format
class Sample
  # Minimum speech duration threshold in seconds for speech activity detection
  SPEECH_DURATION_THRESHOLD = 5 * 60  # 5 minutes

  # @return [Array<String>] Column names for the current format
  attr_accessor :header_array

  # @return [Array<Hash>] Transcript segments with :file, :beg, :end, :text, etc.
  attr_accessor :segments

  # @return [Hash, nil] Optional duration mappings for files
  attr_accessor :durations

  def initialize
    @segments = []
  end

  # Set the header columns for this sample.
  # @param x [Array<String>] Column names (e.g., ['file', 'beg', 'end', 'text'])
  def set_header(x)
    @header_array = x
    @header_string = @header_array.join "\t"
  end

  # Initialize sample from a string in any supported format.
  # Automatically detects the format (TSV, CTM, or JSON) and parses accordingly.
  #
  # @param string [String] The input data to parse
  # @param fn [String, nil] Optional filename for formats that don't include it
  # @return [Sample] Returns self for method chaining
  # @raise [RuntimeError] If format is unknown or sample is already initialized
  def init_from(string:, fn: nil)
    @fn = fn
    raise "already initialized" if @segments.length > 0
    @header = false
    case string
    when /^\S+ 1 / # assume ctm
      set_header %w[ file beg end text ]
      lines = string.lines.map(&:chomp)
      lines.each do |line|
        add_segment_from_ctm line:
      end
    when /^\w/ # assume tsv
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
    x =~ /^\d+(\.\d*)?\z/
  end

  def check_header(line)
    case line
    when /^file\tbeg\tend\ttext(\tspeaker(\tsection)?)?\z/
      @header_string = line
      @header = true
      @header_array = @header_string.split "\t"
    when "start\tend\ttext"
      raise "the file name must be set" if @fn.nil?
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

  # Combine another sample into this one.
  # Headers must match exactly or an error is raised.
  #
  # @param other_sample [Sample] The sample to merge into this one
  # @raise [RuntimeError] If headers don't match
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

  # Assumes the line matches the header.
  # Checks the number of fields, but that's it.
  def add_segment_from_tsv(line:)
    a = line.split "\t", -1
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
    @segments << segment
  end

  def norm(x)
    x.gsub(/[-=#,.?()]/, '').gsub(/  +/, ' ').downcase
  end

  # Parse a JSON object from various ASR vendors and add segments.
  # Automatically detects the vendor format based on object structure.
  #
  # @param object [Hash] Parsed JSON object from ASR service
  # @raise [RuntimeError] If format cannot be detected or filename not set
  def add_object(object:)
    case
    when object['monologues']
      parse_rev(object)
    when object['audio_metrics']
      parse_ibm(object)
    when object['results']
      parse_google_cloud(object)
    when object['source']
      parse_azure(object)
    when object['segments']
      parse_whisper(object)
    when object['transcription']
      parse_whisper_cpp(object)
    when object['pred_text']
      parse_pred_text(object)
    else
      raise "Unknown JSON format: unable to detect ASR vendor"
    end
  end

  private

  def parse_rev(object)
    raise "Filename must be set" if @fn.nil?
    set_header %w[ file beg end text speaker ]
    object['monologues'].each do |m|
      speaker = m['speaker']
      m['elements'].each do |e|
        next unless e['type'] == 'text'
        @segments << {
          file: @fn,
          beg: e['ts'],
          end: e['end_ts'],
          text: e['value'],
          speaker: speaker
        }
      end
    end
  end

  def parse_ibm(object)
    raise "Filename must be set" if @fn.nil?
    set_header %w[ file beg end text speaker ]
    object['results'].each do |result|
      result['alternatives'].first['timestamps'].each do |timestamp|
        next if timestamp[0][0] == '%'
        word, beg_time, end_time = timestamp
        speaker = find_ibm_speaker(object['speaker_labels'], beg_time, end_time)
        @segments << {
          file: @fn,
          beg: beg_time,
          end: end_time,
          text: word,
          speaker: speaker
        }
      end
    end
  end

  def parse_google_cloud(object)
    raise "Filename must be set" if @fn.nil?

    # Determine if this is v1 or v2 format
    first_word = object['results'].last['alternatives'].first['words'].first

    if first_word['startTime'].is_a?(Hash)
      parse_google_cloud_v1(object)
    elsif first_word['startOffset'].is_a?(String) || first_word['startOffset'].nil?
      parse_google_cloud_v2(object)
    else
      raise "Unknown Google Cloud Speech format"
    end
  end

  def parse_google_cloud_v1(object)
    set_header %w[ file beg end text speaker ]
    alternatives = object['results'].last['alternatives']
    if alternatives.first.keys.length == 3
      raise "Unknown format; might be Google Cloud without speaker tags"
    end
    alternatives.first['words'].each do |w|
      @segments << {
        file: @fn,
        beg: google_cloud_timestamp(w['startTime']),
        end: google_cloud_timestamp(w['endTime']),
        text: w['word'],
        speaker: w['speakerTag']
      }
    end
  end

  def parse_google_cloud_v2(object)
    set_header %w[ file beg end text speaker ]
    object['results'].each do |result|
      result['alternatives'].first['words'].each do |w|
        @segments << {
          file: @fn,
          beg: google_cloud_v2_timestamp(w['startOffset']),
          end: google_cloud_v2_timestamp(w['endOffset']),
          text: w['word'],
          speaker: w['speakerLabel']
        }
      end
    end
  end

  def parse_azure(object)
    raise "Filename must be set" if @fn.nil?
    set_header %w[ file beg end text speaker ]
    object['recognizedPhrases'].each do |phrase|
      if phrase['nBest'].count != 1
        raise "Expected exactly 1 nBest result, got #{phrase['nBest'].count}"
      end
      speaker = phrase['speaker'].to_s
      phrase['nBest'].first['words'].each do |word|
        beg_time = (word['offsetMilliseconds'].to_f / 1000).round(3)
        duration = (word['durationMilliseconds'].to_f / 1000).round(3)
        @segments << {
          file: @fn,
          beg: beg_time,
          end: (beg_time + duration).round(3),
          text: word['word'],
          speaker: speaker
        }
      end
    end
  end

  def parse_whisper(object)
    raise "Filename must be set" if @fn.nil?
    set_header %w[ file beg end text ]
    if object['segments'].first['words']
      parse_whisper_with_words(object)
    else
      parse_whisper_without_words(object)
    end
  end

  def parse_whisper_with_words(object)
    object['segments'].each do |segment|
      segment['words'].each do |word|
        @segments << {
          file: @fn,
          beg: word['start'],
          end: word['end'],
          text: word['word'].gsub(/\s/, '')
        }
      end
    end
  end

  def parse_whisper_without_words(object)
    object['segments'].each do |segment|
      words = segment['text'].split
      beg_time = segment['start']
      increment = (segment['end'] - beg_time) / words.length

      words.each_with_index do |word, index|
        end_time = beg_time + increment
        @segments << {
          file: @fn,
          beg: beg_time.round(3),
          end: end_time.round(3),
          text: word.gsub(/\s/, '')
        }
        beg_time = end_time
      end
      # Adjust last segment end time to match segment end
      @segments[-1][:end] = segment['end'] if @segments.any?
    end
  end

  def parse_whisper_cpp(object)
    raise "Filename must be set" if @fn.nil?
    set_header %w[ file beg end text ]
    return if object['transcription'].empty?

    object['transcription'].each do |item|
      next if item['text'].empty?
      @segments << {
        file: @fn,
        beg: (item['offsets']['from'].to_f / 1000).round(3),
        end: (item['offsets']['to'].to_f / 1000).round(3),
        text: item['text']
      }
    end
  end

  def parse_pred_text(object)
    filename = object['audio_filepath']
    # TODO: Make audio base path configurable instead of hardcoding
    duration = `soxi -D /clinical/poetry/#{filename}`.to_f
    set_header %w[ file beg end text ]
    @segments << {
      file: File.basename(filename, '.wav'),
      beg: 0.0,
      end: duration,
      text: object['pred_text']
    }
  end

  # Helper methods for timestamp conversions

  def find_ibm_speaker(speaker_labels, beg_time, end_time)
    # Brute force search - could be optimized with binary search
    matching_labels = speaker_labels.select { |label|
      beg_time >= label['from'] && end_time <= label['to']
    }
    if matching_labels.count != 1
      raise "Could not find unique speaker label for segment #{beg_time}-#{end_time} (found #{matching_labels.count})"
    end
    matching_labels.first['speaker'].to_s
  end

  def google_cloud_timestamp(time_obj)
    time_obj['nanos'].to_f / 1_000_000_000 + time_obj['seconds'].to_f
  end

  def google_cloud_v2_timestamp(time_string)
    return 0.0 if time_string.nil?
    time_string.sub('s', '').to_f
  end

  public

  def print_prep(norm: false, after_time: nil, after_time_with_map: nil, strip_extensions: true)
    @segments.each do |x|
      x[:file] = x[:file].sub(/^.+\//, '')
      x[:file] = x[:file].sub(/\.\w+$/, '') if strip_extensions
      x[:text] = norm x[:text] if norm
    end
    puts @header_string
    if after_time
      @segments.select { |x| x[:end] > after_time }
    elsif after_time_with_map
      @segments.select { |x| x[:end] > after_time_with_map[x[:file]] }
    else
      @segments
    end
  end

  def print(norm: false, after_time: nil, after_time_with_map: nil, strip_extensions: true)
    segments = print_prep(norm: , after_time: , after_time_with_map: , strip_extensions: )
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
      end
    end
    puts a.map { |x| segment2line x }
  end

  def fix_parens(x)
    x = x.gsub('(())', 'x')
    .gsub(/{\w+}/,'')
    .gsub(/[-=#()?!.,\/$%+~{}\[\]]/, '')
    encoding_options = {
      :invalid           => :replace,  # Replace invalid byte sequences
      :undef             => :replace,  # Replace anything not defined in ASCII
      :replace           => '',        # Use a blank for those replacements
      :universal_newline => true       # Always break lines with \n
    }
    x
  end

  # Convert segments to NIST STM (Segment Time Mark) format.
  # @return [String] STM formatted output
  def stm
    @segments.map do |x|
      [
        x[:file],
        'A',
        x[:speaker],
        x[:beg],
        x[:end],
        fix_parens(x[:text])
      ].join ' '
    end.join("\n") + "\n"
  end

  # Convert segments to NIST CTM (Conversation Time Marked) format.
  # Splits multi-word segments into individual word entries.
  # @return [String] CTM formatted output
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
        spk = '`'.dup unless map[y[:file]]
        map[y[:file]] ||= {}
        map[y[:file]][y[:speaker]] ||= spk.succ!.dup
      else
        speaker
      end
      segment2line y
    }
  end

  # Normalize speaker labels to sequential letters (a, b, c, ...) per file.
  # @return [Array<String>] Array of formatted segment lines
  def normalize_speakers
    map = {}
    spk = nil
    segments.map { |x|
      y = x.dup
      spk = '`'.dup unless map[y[:file]]
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
    offset = durations[@segments[0][:file]] / 2
    @segments.each_with_index do |x, i|
      b, e = x[:beg], x[:end]
      if x[:text] == 'speech' and b >= offset
        s ||= (b + @segments[i-1][:end]) / 2
        t += e - b
        if t >= SPEECH_DURATION_THRESHOLD
          action1(s, e, i)
          break
        end
      end
    end
  end

  def action1(s, e, i)
    pad = (@segments[i+1][:beg] - e) / 2
    ee = (e + pad) - s
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

  # Count unintelligible markers (tokens starting with '((') per file.
  # @return [Hash] Map of filename to count of unintelligible tokens
  def count_unintelligible
    files = {}
    @segments.each do |x|
      files[x[:file]] ||= 0
      files[x[:file]] += x[:text].split.count { |x| x =~ /^\(\(/ }
    end
    files
  end

  # Calculate total overlapping speech duration per file.
  # @return [Hash] Map of filename to total overlap duration in seconds
  def count_overlap
    files = {}
    overlap = {}
    @segments.each do |x|
      files[x[:file]] ||= []
      files[x[:file]] << x
      overlap[x[:file]] ||= 0
      files[x[:file]].each do |y|
        next if x == y
        if x[:end] > y[:beg] and x[:beg] < y[:end]
          b = x[:beg] > y[:beg] ? x[:beg] : y[:beg]
          e = x[:end] < y[:end] ? x[:end] : y[:end]
          o = e - b
          overlap[x[:file]] += o
        end
      end
    end
    overlap
  end

  # Calculate average segment length per file.
  # @return [Hash] Map of filename to average segment duration in seconds
  def average_segment_length
    files = {}
    @segments.each do |x|
      files[x[:file]] ||= []
      files[x[:file]] << (x[:end] - x[:beg])
    end

    result = {}
    files.each do |file, durations|
      result[file] = durations.sum / durations.length.to_f
    end
    result
  end

  # Calculate average gap between consecutive segments per file.
  # Gaps are calculated only between consecutive segments within the same file.
  # @return [Hash] Map of filename to average gap duration in seconds
  def average_segment_gap
    files = {}
    @segments.each do |x|
      files[x[:file]] ||= []
      files[x[:file]] << x
    end

    result = {}
    files.each do |file, segs|
      # Sort segments by begin time
      sorted = segs.sort_by { |s| s[:beg] }
      gaps = []

      sorted.each_cons(2) do |current, next_seg|
        gap = next_seg[:beg] - current[:end]
        gaps << gap if gap >= 0
      end

      result[file] = gaps.empty? ? 0.0 : gaps.sum / gaps.length.to_f
    end
    result
  end

  # Calculate comprehensive segment statistics per file.
  # @param combined [Boolean] If true, calculate averages across all segments (gaps still within file boundaries)
  # @return [Hash] Map of filename to stats hash with :avg_length, :avg_gap, :count
  def segment_statistics(combined: false)
    if combined
      return {} if @segments.empty?

      # Group by file to calculate gaps within each file
      files = {}
      @segments.each do |x|
        files[x[:file]] ||= []
        files[x[:file]] << x
      end

      # Collect all segment lengths
      all_lengths = @segments.map { |s| s[:end] - s[:beg] }

      # Collect all gaps (calculated within each file)
      all_gaps = []
      files.each do |file, segs|
        sorted = segs.sort_by { |s| s[:beg] }
        sorted.each_cons(2) do |current, next_seg|
          gap = next_seg[:beg] - current[:end]
          all_gaps << gap if gap >= 0
        end
      end

      return {
        'combined' => {
          avg_length: all_lengths.sum / all_lengths.length.to_f,
          avg_gap: all_gaps.empty? ? 0.0 : all_gaps.sum / all_gaps.length.to_f,
          count: @segments.length,
          total_length: all_lengths.sum
        }
      }
    end

    # Original per-file behavior
    files = {}
    @segments.each do |x|
      files[x[:file]] ||= []
      files[x[:file]] << x
    end

    result = {}
    files.each do |file, segs|
      # Sort segments by begin time
      sorted = segs.sort_by { |s| s[:beg] }

      # Calculate segment lengths
      lengths = sorted.map { |s| s[:end] - s[:beg] }

      # Calculate gaps
      gaps = []
      sorted.each_cons(2) do |current, next_seg|
        gap = next_seg[:beg] - current[:end]
        gaps << gap if gap >= 0
      end

      result[file] = {
        avg_length: lengths.sum / lengths.length.to_f,
        avg_gap: gaps.empty? ? 0.0 : gaps.sum / gaps.length.to_f,
        count: segs.length,
        total_length: lengths.sum
      }
    end
    result
  end

  # Merge consecutive segments when gap is below threshold.
  # Only merges segments from the same file with the same speaker (if present).
  #
  # @param threshold [Float] Maximum gap in seconds to allow merging
  # @return [Sample] New Sample with merged segments
  def merge_segments(threshold:)
    # Group segments by file
    files = {}
    @segments.each do |x|
      files[x[:file]] ||= []
      files[x[:file]] << x
    end

    merged_sample = Sample.new
    merged_sample.set_header(@header_array)

    files.each do |file, segs|
      # Sort segments by begin time
      sorted = segs.sort_by { |s| s[:beg] }
      next if sorted.empty?

      # Start with first segment
      current_merged = sorted.first.dup

      sorted[1..-1].each do |seg|
        gap = seg[:beg] - current_merged[:end]

        # Check if we should merge:
        # 1. Gap must be less than threshold
        # 2. Speaker must match (if speaker field exists)
        should_merge = gap < threshold

        if @header_array.include?('speaker')
          should_merge = should_merge && (seg[:speaker] == current_merged[:speaker])
        end

        if should_merge
          # Merge: extend end time and concatenate text
          current_merged[:end] = seg[:end]
          current_merged[:text] = "#{current_merged[:text]} #{seg[:text]}"
        else
          # Don't merge: save current merged segment and start new one
          merged_sample.segments << current_merged
          current_merged = seg.dup
        end
      end

      # Don't forget the last segment
      merged_sample.segments << current_merged
    end

    merged_sample
  end

end

