require 'shopify_api'
require 'sinatra'
require 'httparty'
require 'dotenv/load'

# for debug
require 'pry'

class App < Sinatra::Base
  attr_accessor :tokens

  API_KEY     = ENV['API_KEY']
  API_SECRET  = ENV['API_SECRET']
  API_VERSION = '2019-10'

  # Use ngrok development URL
  APP_URL = ''

  def initialize
    @tokens = {}
    super
  end

  # FIXME: Cannot render in Shopify Admin
  get '/' do
    send_file './index.html'
  end

  get '/app/install' do
    shop = request.params['shop']
    scopes = 'read_orders,read_products,write_products'

    # construct the installation URL and redirect the merchant
    install_url =
      "http://#{shop}/admin/oauth/authorize?client_id=#{API_KEY}"\
      "&scope=#{scopes}&redirect_uri=https://#{APP_URL}/app/auth"

    # redirect to the install_url
    redirect install_url
  end

  get '/app/auth', :provides => 'html' do
    # extract shop data from request parameters
    shop = request.params['shop']
    code = request.params['code']
    hmac = request.params['hmac']

    # perform hmac validation to determine if the request is coming from Shopify
    validate_hmac(hmac, request)

    # if no access token for this particular shop exist,
    # POST the OAuth request and receive the token in the response
    get_shop_access_token(shop, API_KEY, API_SECRET, code)

    # create webhook for order creation if it doesn't exist
    # create_order_webhook

    # now that the session is activated, redirect to the bulk edit page
    redirect '/'
  end

  # post '/app/webhook/order_create' do
  #   # inspect hmac value in header and verify webhook
  #   hmac = request.env['HTTP_X_SHOPIFY_HMAC_SHA256']
  #
  #   request.body.rewind
  #   data = request.body.read
  #   webhook_ok = verify_webhook(hmac, data)
  #
  #   if webhook_ok
  #     shop = request.env['HTTP_X_SHOPIFY_SHOP_DOMAIN']
  #     token = @tokens[shop]
  #
  #     unless token.nil?
  #       session = ShopifyAPI::Session.new(shop, token)
  #       ShopifyAPI::Base.activate_session(session)
  #     else
  #       return [403, "You're not authorized to perform this action."]
  #     end
  #   else
  #     return [403, "You're not authorized to perform this action."]
  #   end
  #
  #   # parse the request body as JSON data
  #   json_data = JSON.parse data
  #
  #   line_items = json_data['line_items']
  #
  #   line_items.each do |line_item|
  #     variant_id = line_item['variant_id']
  #
  #     variant = ShopifyAPI::Variant.find(variant_id)
  #
  #     variant.metafields.each do |field|
  #       if field.key == 'ingredients'
  #         items = field.value.split(',')
  #
  #         items.each do |item|
  #           gift_item = ShopifyAPI::Variant.find(item)
  #           gift_item.inventory_quantity = gift_item.inventory_quantity - 1
  #           gift_item.save
  #         end
  #       end
  #     end
  #   end
  #
  #   return [200, "Webhook notification received successfully."]
  # end

  helpers do
    def get_shop_access_token(shop, client_id, client_secret, code)
      return unless tokens[shop].nil?

      url = "https://#{shop}/admin/oauth/access_token"
      payload = {
        client_id:     client_id,
        client_secret: client_secret,
        code:          code
      }

      response = HTTParty.post(url, body: payload)

      # if the response is successful, obtain the token and store it in a hash
      return [500, 'Something went wrong.'] unless response.code == 200

      tokens[shop] = response['access_token']
      instantiate_session(shop)
    end

    def instantiate_session(shop)
      # now that the token is available, instantiate a session
      session = ShopifyAPI::Session.new(
        domain: shop, token: tokens[shop], api_version: API_VERSION
      )
      ShopifyAPI::Base.activate_session(session)
    end

    def validate_hmac(hmac,request)
      h = request.params.reject { |k, _| k == 'hmac' || k == 'signature' }
      query = URI.escape(h.sort.collect { |k, v| "#{k}=#{v}" }.join('&'))
      digest = OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('sha256'), API_SECRET, query
      )
      return if hmac == digest

      [403, "Authentication failed. Digest provided was: #{digest}"]
    end

    # def verify_webhook(hmac, data)
    #   digest = OpenSSL::Digest.new('sha256')
    #   calculated_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, API_SECRET, data)).strip
    #
    #   hmac == calculated_hmac
    # end

    # def bulk_edit_url
    #   'https://www.shopify.com/admin/bulk'\
    #     '?resource_name=ProductVariant'\
    #     '&edit=metafields.test.ingredients:string'
    # end

    # def create_order_webhook
    #   # create webhook for order creation if it doesn't exist
    #   return if ShopifyAPI::Webhook.find(:all).any?
    #
    #   webhook = {
    #     topic: 'orders/create',
    #     address: "https://#{APP_URL}/giftbasket/webhook/order_create",
    #     format: 'json'}
    #
    #   ShopifyAPI::Webhook.create(webhook)
    # end
  end
end

run App.run!
