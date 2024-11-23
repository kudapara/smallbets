class GumroadAPI
  BASE_URL = "https://api.gumroad.com/v2"

  class << self
    attr_accessor :access_token

    def sales(params = {})
      endpoint = "/sales"
      all_sales = get(endpoint, params.merge(product_id:))["sales"] || []

      all_sales.reject { |sale| sale["refunded"] || sale["chargedback"] }
    end

    private

    def get(endpoint, params = {})
      raise "Access token is not set" unless @access_token

      uri = URI("#{BASE_URL}#{endpoint}")
      params[:access_token] = @access_token
      uri.query = URI.encode_www_form(params)

      response = Net::HTTP.get_response(uri)
      handle_response(response)
    end

    def handle_response(response)
      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      else
        { "success" => false, "error" => response.message, "code" => response.code }
      end
    end

    def product_id
      ENV["GUMROAD_PRODUCT_ID"]
    end
  end
end
