# coding: utf-8

require 'fig/user_input_error'

module Fig
  # Package definition attempted to specify a URL outside of the whitelist.
  class URLAccessDisallowedError < UserInputError
    attr_reader :urls, :descriptor

    def initialize(urls, descriptor)
      @urls       = urls
      @descriptor = descriptor
    end

    def message
      "URLAccessDisallowedError:\n  descriptor = #{descriptor.inspect}\n  urls = " +
        @urls.map { |k,v| " - #{k}: #{v.inspect}" }.join("\n    ")
    end
  end
end
