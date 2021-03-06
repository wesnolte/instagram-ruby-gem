require 'faraday'

# @private
module FaradayMiddleware
  # @private
  class RaiseHttpException < Faraday::Middleware
    def call(env)
      @app.call(env).on_complete do |response|
        case response[:status].to_i
        when 400
          raise Instagram::BadRequest, error_message_400(response)
        when 404
          raise Instagram::NotFound, error_message_400(response)
        when 500
          raise Instagram::InternalServerError, error_message_500(response, "Something is technically wrong.")
        when 503
          raise Instagram::ServiceUnavailable, error_message_500(response, "Instagram is rate limiting your requests.")
        end
      end
    end

    def initialize(app)
      super app
      @parser = nil
    end

    private

    def error_message_400(response)
      # response body is escaped JSON so it needs to be parsed
      body = ::JSON.parse(response[:body])
      
      "#{response[:method].to_s.upcase} #{response[:url].to_s}: #{response[:status]}#{error_body(body)}"
    end

    def error_body(body)
      if body.nil?
        nil
      elsif body['meta'] and body['meta']['error_message'] and not body['meta']['error_message'].empty?
        ": #{body['meta']['error_type']} - #{body['meta']['error_message']}"
      end
    end

    def error_message_500(response, body=nil)
      "#{response[:method].to_s.upcase} #{response[:url].to_s}: #{[response[:status].to_s + ':', body].compact.join(' ')}"
    end
  end
end
