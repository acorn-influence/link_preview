require 'faraday'
require 'faraday/follow_redirects'

module Faraday
  class Response
    def url
      finished? ? env[:url] : nil
    end
  end
end

module LinkPreview
  class ExtraEnv < Faraday::Middleware
    class << self
      attr_accessor :extra
    end

    def call(env)
      env[:link_preview] = self.class.extra || {}
      @app.call(env)
    ensure
      env[:link_preview] = nil
    end
  end

  class NormalizeURI < Faraday::Middleware
    def call(env)
      env[:url] = env[:url].normalize
      @app.call(env)
    end
  end

  class HTTPClient
    extend Forwardable

    def initialize(config)
      @config = config
    end

    def_delegator :faraday_connection, :get

    private

    def faraday_connection
      @faraday_connection ||= Faraday.new do |builder|
        builder.options[:timeout] = @config.timeout
        builder.options[:open_timeout] = @config.open_timeout

        builder.use ExtraEnv
        builder.use Faraday::FollowRedirects, limit: @config.max_redirects if @config.follow_redirects
        builder.use NormalizeURI
        @config.middleware.each { |middleware| builder.use middleware }

        builder.use @config.http_adapter
      end
    end
  end
end
