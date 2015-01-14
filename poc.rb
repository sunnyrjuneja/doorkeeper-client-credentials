#!/usr/bin/env ruby
require File.expand_path('../config/environment',  __FILE__)

email = 'example@gmail.com'
password = 'password'
redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'

user = User.create(email: email, password: password, password_confirmation: password)
app = Doorkeeper::Application.create!(name: 'App', redirect_uri: redirect_uri)

client = OAuth2::Client.new(app.uid, app.secret) do |c|
  c.request :url_encoded
  c.adapter :rack, Rails.application
end

token = client.password.get_token(email, password)

puts "Expired? #{token.expired}?"
puts "Token: #{token.token}?"

byebug
user.destroy
app.destroy
