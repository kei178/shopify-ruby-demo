# shopify-ruby-demo

A demo app with Ruby &amp; Sinatra for Shopify Admin app (development use only)


## Requirements
* Ruby
* [ngrok](https://ngrok.com/download)
* Shopify Partners account

## Run

Start ngrok with port 4567.

```
./ngrok http 4567
```

Copry the ngrok URL and add it in app.rb & the Shopify App settings.

Run the Sinatra app.

```
ruby app.rb
```

## Reference
* [Build a Shopify app with Ruby and Sinatra - Shopify Developers](https://help.shopify.com/en/api/tutorials/build-a-shopify-app-with-ruby-and-sinatra)
