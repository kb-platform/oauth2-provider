require 'factory_girl'

Factory.sequence :client_name do |n|
  "Client ##{n}"
end

Factory.sequence :user_name do |n|
  "User ##{n}"
end

Factory.define :owner, :class => TestApp::User do |u|
  u.name { Factory.next :user_name }
end

Factory.define :client, :class => OAuth2::Model::Client do |c|
  c.client_id     { OAuth2::Lib::SecureCodeScheme.random_string }
  c.client_secret { OAuth2::Lib::SecureCodeScheme.random_string }
  c.name          { Factory.next :client_name }
  c.redirect_uri  'https://client.example.com/cb'
  c.owner
end

Factory.define :native_client, :class => OAuth2::Model::Client do |c|
  c.client_id     { OAuth2::Lib::SecureCodeScheme.random_string }
  c.client_secret { OAuth2::Lib::SecureCodeScheme.random_string }
  c.name          { Factory.next :client_name }
  c.redirect_uri  'exampleapp://client.example.com/cb'
  c.client_type   'native_app'
  c.owner
end
