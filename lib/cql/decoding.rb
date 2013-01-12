# encoding: utf-8

module Cql
  DecodingError = Class.new(CqlError)

  module Decoding
    extend self

    def read_int!(buffer)
      raise DecodingError, "Need four bytes to decode an int, only #{buffer.size} bytes given" if buffer.size < 4
      buffer.slice!(0, 4).unpack(INT_FORMAT).first
    end

    def read_short!(buffer)
      raise DecodingError, "Need two bytes to decode a short, only #{buffer.size} bytes given" if buffer.size < 2
      buffer.slice!(0, 2).unpack(SHORT_FORMAT).first
    end

    def read_string!(buffer)
      length = read_short!(buffer)
      raise DecodingError, "String length is #{length}, but only #{buffer.size} bytes given" if buffer.size < length
      string = buffer.slice!(0, length)
      string.force_encoding(::Encoding::UTF_8)
      string
    end

    def read_long_string!(buffer)
      length = read_int!(buffer)
      raise DecodingError, "String length is #{length}, but only #{buffer.size} bytes given" if buffer.size < length
      string = buffer.slice!(0, length)
      string.force_encoding(::Encoding::UTF_8)
      string
    end

    def read_uuid!(buffer)
      raise NotImplementedError
    end

    def read_string_list!(buffer)
      size = read_short!(buffer)
      size.times.map do
        read_string!(buffer)
      end
    end

    def read_bytes!(buffer)
      size = read_int!(buffer)
      return nil if size & 0x80000000 == 0x80000000
      raise DecodingError, "Byte array length is #{size}, but only #{buffer.size} bytes given" if buffer.size < size
      bytes = buffer.slice!(0, size)
      bytes.force_encoding(::Encoding::BINARY)
      bytes
    end

    def read_short_bytes!(buffer)
      size = read_short!(buffer)
      return nil if size & 0x8000 == 0x8000
      raise DecodingError, "Byte array length is #{size}, but only #{buffer.size} bytes given" if buffer.size < size
      bytes = buffer.slice!(0, size)
      bytes.force_encoding(::Encoding::BINARY)
      bytes
    end

    def read_option!(buffer)
      id = read_short!(buffer)
      value = nil
      if block_given?
        value = yield id, buffer
      end
      [id, value]
    end

    def read_option_list!(buffer)
      raise NotImplementedError
    end

    def read_inet!(buffer)
      raise NotImplementedError
    end

    def read_consistency!(buffer)
      index = read_short!(buffer)
      raise DecodingError, "Unknown consistency index #{index}" unless index < CONSISTENCIES.size
      CONSISTENCIES[index]
    end

    def read_string_map!(buffer)
      map = {}
      map_size = read_short!(buffer)
      map_size.times do
        key = read_string!(buffer)
        map[key] = read_string!(buffer)
      end
      map
    end

    def read_string_multimap!(buffer)
      map = {}
      map_size = read_short!(buffer)
      map_size.times do
        key = read_string!(buffer)
        map[key] = read_string_list!(buffer)
      end
      map
    end

    private

    INT_FORMAT = 'N'.freeze
    SHORT_FORMAT = 'n'.freeze
  end
end