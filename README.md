## Doorkeeper Client Credentials

This is a proof of concept repo for [Doorkeeper#543](https://github.com/doorkeeper-gem/doorkeeper/issues/543).
The goal is to show that Doorkeeper is ignoring the configuration option **not to** 
accept username and password in parameters.

# Explanation

All of the logic necessary to replicate this exists in poc.rb. It'll be annotated here:

```ruby
# poc.rb
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

# The implementation of get_token is here:
# https://github.com/intridea/oauth2/blob/master/lib/oauth2/strategy/password.rb#L19-L23
# def get_token(username, password, params = {}, opts = {})
#   params = {'grant_type' => 'password',
#             'username'   => username,
#             'password'   => password}.merge(client_params).merge(params)
#   @client.get_token(params, opts)
# end
# As we can, it add the username and password to the parameters.
# There is a PR here to make basic auth default here:
# https://github.com/intridea/oauth2/pull/192

token = client.password.get_token(email, password)

puts "Expired? #{token.expired}?"
puts "Token: #{token.token}?"

# byebug will drop you into the debugger
byebug

# remove the records to rerun the poc
user.destroy
app.destroy
```

We can confirm this with the logs (log/development.log) which show that oauth2
is sending parameters in the post and the server is accepting it.

```
Started POST "/oauth/token" for 127.0.0.1 at 2015-01-14 14:46:56 -0800
  [1m[35mActiveRecord::SchemaMigration Load (0.1ms)[0m  SELECT "schema_migrations".* FROM "schema_migrations"
Processing by Doorkeeper::TokensController#create as HTML
  Parameters: {"client_id"=>"38413cf165f1a76df10d621859e1a44e320fa954b41b5aafd9c249c1411f78c3", "client_secret"=>"614453412baad0e87123832df327382e756c903ed56bf957ab9eeaf3e7e39c56", "grant_type"=>"password", "password"=>"[FILTERED]", "username"=>"example@gmail.com"}
  [1m[36mUser Load (0.2ms)[0m  [1mSELECT  "users".* FROM "users" WHERE "users"."email" = ?  ORDER BY "users"."id" ASC LIMIT 1[0m  [["email", "example@gmail.com"]]
  [1m[35m (0.1ms)[0m  begin transaction
  [1m[36mDoorkeeper::AccessToken Exists (0.1ms)[0m  [1mSELECT  1 AS one FROM "oauth_access_tokens" WHERE "oauth_access_tokens"."token" = '0fb324dcd4b57022bbe60800ce97e6f12f193170295b460bd34e68b9540dbccf' LIMIT 1[0m
  [1m[35mDoorkeeper::AccessToken Exists (0.1ms)[0m  SELECT  1 AS one FROM "oauth_access_tokens" WHERE "oauth_access_tokens"."refresh_token" = 'aad4fa65f084d6a963b240fa42ad3fa3c81c2fa20e8dac0e2b25bdf60b6ed43d' LIMIT 1
  [1m[36mSQL (0.2ms)[0m  [1mINSERT INTO "oauth_access_tokens" ("resource_owner_id", "scopes", "expires_in", "token", "refresh_token", "created_at") VALUES (?, ?, ?, ?, ?, ?)[0m  [["resource_owner_id", 1], ["scopes", ""], ["expires_in", 7200], ["token", "0fb324dcd4b57022bbe60800ce97e6f12f193170295b460bd34e68b9540dbccf"], ["refresh_token", "aad4fa65f084d6a963b240fa42ad3fa3c81c2fa20e8dac0e2b25bdf60b6ed43d"], ["created_at", "2015-01-14 22:46:56.179794"]]
  [1m[35m (11.0ms)[0m  commit transaction
Completed 200 OK in 96ms
```

And the config is explicitly set not to accept params:

```ruby
# config/initializers/doorkeeper.rb

Doorkeeper.configure do

  # Other options omitted

  # Change the way client credentials are retrieved from the request object.
  # By default it retrieves first from the `HTTP_AUTHORIZATION` header, then
  # falls back to the `:client_id` and `:client_secret` params from the `params` object.
  # Check out the wiki for more information on customization
  client_credentials :from_basic

  # Change the way access token is authenticated from the request object.
  # By default it retrieves first from the `HTTP_AUTHORIZATION` header, then
  # falls back to the `:access_token` or `:bearer_token` params from the `params` object.
  # Check out the wiki for more information on customization
  access_token_methods :from_bearer_authorization

  # Specify what grant flows are enabled in array of Strings. The valid
  # strings and the flows they enable are:
  #
  # "authorization_code" => Authorization Code Grant Flow
  # "implicit"           => Implicit Grant Flow
  # "password"           => Resource Owner Password Credentials Grant Flow
  # "client_credentials" => Client Credentials Grant Flow
  #
  # If not specified, Doorkeeper enables all the four grant flows.
  #
  grant_flows %w(password)
end
```
