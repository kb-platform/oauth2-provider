# OAuth2::Provider

![Build Status](https://travis-ci.org/FlickElectric/oauth2-provider.svg?branch=master)

In the good old OAuth2 days; before wrote his [caustic rant](https://hueniverse.com/2012/07/26/oauth-2-0-and-the-road-to-hell/) highlighting its problems, before OpenIdConnect was even invented, this Gem appeared from SongKick (no longer with us) to handle the new protocol.  This gem attempts to handle the OAuth2 world.  But where we are using OpenIdConnect, and managing authentication through Devise (itself a massive framework), and are starting to add protocols for mobile Oauth2 behaviour, we are not reliant on all the gem offers.  

So, if you want to read about its Universe, track down the original Gem, otherwise, here you'll find more about the Flick use of the provider gem.

The Provider is designed to be usable within any web frontend, at least those of
Rails and Sinatra. Its API uses Rack request-environment hashes rather than
framework-specific request objects, though you can pass those in and their
`request.env` property will be used internally.

It stores the clients and authorizations using ActiveRecord.


## Installation

```
gem install oauth2-provider
```


## A note on versioning

This library was based on [draft-10](http://tools.ietf.org/html/draft-ietf-oauth-v2-10).
of the spec.  This still remains, sort of, true, but we have added to this baseline:

* OpenId Connect tokens
* PKCE Support; as for all good standards this has a fantastically catchy name; __Proof Key for Code Exchange by OAuth Public Clients__; although we kinda like __Pixie__


During draft state, the gem version will indicate which draft it implements
using the minor version, for example `0.10.2` means the second bug-fix
release for draft 10.


## Terminology

* **Client**: A third-party software system that integrates with the provider.  In OpenIdConnect this known as the **Relying Party**.
* **Client Owner**: The entity which owns a **client**, i.e. the
  individual or company responsible for the client application.
* **Resource Owner**: This will almost certainly be a User. It's the entity
  which has the data that the *client* is asking permission to see.
* **Authorization**: When a **resource owner** grants access to a
  **client** (i.e., a user grants access to a company's app), an
  authorization is created. This can be revoked by the user. Revocation is not provided in the gem, but rather is the responsibility of the service.
* **Access Token**: An opaque string representing an **authorization**.  We **DONT USE** access_tokens anymore.  Call it an amicable breakup!  Our tokens are....
* **Identity Tokens**.  Id tokens are defined in [OpenIdConnect](http://openid.net/specs/openid-connect-core-1_0.html) and serialised as JSON Web Tokens (JWT).  They are signed using RSA public-key mechanisms.



## Usage

### Setup

After all that `bundle` stuff, we need a little configuration:

```ruby
OAuth2::Provider.realm = 'Flick Auth'                     # it likes a Realm, but we dont use it.
OAuth2::Provider.default_duration = 2.months              # Unless overridden, the default token
                                                          # expiry
OAuth2::Provider.token_decoder = [FlickAuth::Jwt, :decode]# The class which will decode the JWT
                                                          # The default is [JSON::JWT, :decode]
OAuth2::Provider.issuer = ENV["FLICK_API_ENDPOINT"]       # The iss property of the id_token.
```

The Provider also requires a number of keys to be established in the environment:

* `PRIVATE_KEY`; which must be an RSA private key.
* The PKCE mechanism requires that `CIPHER_KEY` and a `CIPHER_IV` environment variables be set.  These provide the key and initialisation vector for AES encryption.  Creating these are straightforward:

```ruby
cipher = OpenSSL::Cipher::AES.new(256, :CBC)
iv = cipher.random_iv
key = cipher.random_key
```

If you are going to support the Client Credentials Grant, you'll also want to provide a block that responds to `call` (like all good blocks), takes `client`, `owner`, `scopes`, and implements a possible access grant.  For example:

```ruby
OAuth2::Provider.handle_client_credentials do |client, owner, scopes|
  if owner
    owner.grant_access!(client, scopes: scopes, duration: OAuth2::Provider.default_duration)
  else
    nil
  end
end

```

### Modes of Calling the Provider

Any Oauth2 request (any grant type and the token request) can be parsed by the provide through the following method:

```ruby
OAuth2::Provider.parse(user, env).call
```
This returns one of the 2 Oauth handlers; the `OAuth2::Provider::Authorisation` which deals with the authorisation requests, and `OAuth2::Provider::Exchange` which deals with token exchange.

#### Authorisation

Provides the following methods:

* `#scopes`
* `#unauthorized_scopes`
* `#grant_access!`
* `#deny_access!`
* `#redirect?`
* `#valid?`
* `#relying_party`
* `#resource_owner_model`
* `#native_app_client?`

#### Exchange

Provides the following methods:

* `#generate_id_token`
* `#response_body`
* `#response_status`
* `#scopes`
* `#valid?`
* `#update_authorization`
* `#relying_party`
* `#owner_model`



### Creating the Provider Models

Add the `OAuth2::Provider` tables to your app's schema. This is
done using `OAuth2::Model::Schema.migrate`, which will run all
the gem's migrations that have not yet been applied to your database.

```
  OAuth2::Model::Schema.migrate
  I, [2012-10-31T14:52:33.801428 #7002]  INFO -- : Migrating to Oauth2SchemaOriginalSchema (20120828112156)
  ==  Oauth2SchemaOriginalSchema: migrating =============================
  -- create_table(:oauth2_clients)
     -> 0.0029s
  -- add_index(:oauth2_clients, [:client_id])
     -> 0.0009s
  ...
```

To rollback migrations, use ```OAuth2::Model::Schema.rollback```.


## Model Mixins

There are two mixins you need to put in your code,
`OAuth2::Model::ClientOwner` for whichever model will own the
"apps", and `OAuth2::Model::ResourceOwner` for whichever model
is the innocent, unassuming entity who will selectively share their data. It's
possible that this is the same model, such as User:

```ruby
class User < ActiveRecord::Base
  include OAuth2::Model::ResourceOwner
  include OAuth2::Model::ClientOwner
  has_many :interesting_pieces_of_data
end
```

Or they might go into two different models:

```ruby
class User < ActiveRecord::Base
  include OAuth2::Model::ResourceOwner
  has_many :interesting_pieces_of_data
end

class Company < ActiveRecord::Base
  include OAuth2::Model::ClientOwner
  belongs_to :user
end
```

To see the methods and associations that these two mixins add to your models,
take a look at `lib/oauth2/model/client_owner.rb` and
`lib/oauth2/model/resource_owner.rb`.


## OAuth Request Endpoint

This is a path that your application exposes in order for clients to communicate
with your application. It is also the page that the client will send users to
so they can authenticate and grant access. Many requests to this endpoint will
be protocol-level requests that do not involve the user, and
`OAuth2::Provider` gives you a generic way to handle all that.

You should use this to get the right response, status code and headers to send
to the client. In the event that `OAuth2::Provider` does not
provide a response, you should render a page that lets the user begin to
authenticate and grant access. This can happen in two cases:

* The client makes a valid Authorization request. In this case you should
  display a login flow to the user so they can authenticate and grant access to
  the client.
* The client makes an invalid Authorization request and the provider cannot
  redirect back to the client. In this case you should display an error page
  to the user, possibly including the value of `@oauth2.error_description`.

Authorisation is usually provided through a `get`, while the token exchange happens via a `post`.  The authorisation exposes the OAuth service through the path `/oauth/authorize`. We check if
there is a logged-in resource owner and give this to `OAuth::Provider`,
since we may be able to immediately redirect if the user has already authorized
the client:

```ruby
@owner  = User.find_by_id(session[:user_id])
@oauth2 = OAuth2::Provider.parse(@owner, env).call

if @oauth2.redirect?
  redirect @oauth2.redirect_uri, @oauth2.response_status
end

headers @oauth2.response_headers
status  @oauth2.response_status

if body = @oauth2.response_body
  body
elsif @oauth2.valid?
  erb :login
else
  erb :error
end
```

There is a set of parameters that you will need to hold on to for when your app
needs to redirect back to the client, or in fact redirect within the app. You could store them in the session, or
pass them through forms as the user completes the flow. For example to embed
them in the login form, do this:

```
<% @oauth2.params.each do |key, value| %>
  <input type="hidden" name="<%= key %>" value="<%= value %>">
<% end %>
```

You may also want to use scopes to provide granular access to your domain using
`scopes`. The `@oauth2` object exposes the scopes the client has
asked for so you can display them to the user:

```
<p>The application <%= @oauth2.client.name %> wants the following permissions:</p>

<ul>
  <% @oauth2.scopes.each do |scope| %>
    <li><%= PERMISSION_UI_STRINGS[scope] %></li>
  <% end %>
</ul>
```

You can also use the method `@oauth2.unauthorized_scopes` to get the list
of scopes the user has not already granted to the client, in the case where the
client already has some authorization. If no prior authorization exists between
the user and the client, `@oauth2.unauthorized_scopes` just returns all
the scopes the client has asked for.


## Granting access to clients

Once the user has authenticated you should show them a page to let them grant
or deny access to the client application. Let's say the
user checks a box before posting a form to indicate their intent:

```ruby
post '/oauth/allow' do
  @user = User.find_by_id(session[:user_id])
  @auth = OAuth2::Provider.parse(@owner, env).call

  if params['allow'] == '1'
    @auth.grant_access!
  else
    @auth.deny_access!
  end
  redirect @auth.redirect_uri, @auth.response_status
end
```

After granting or denying access, we just redirect back to the client using a
URI that `OAuth2::Provider` will provide for you.


## Using Password Credentials

If you like, OAuth lets you use a user's login credentials to authenticate with
a provider. In this case the client application must request these credentials
directly from the user and then post them to the exchange endpoint. On the
provider side you can handle this using the `handle_passwords` and
`grant_access!` API methods, for example:

```ruby
OAuth2::Provider.handle_passwords do |client, username, password, scopes|
  user = User.find_by_username(username)
  if user.authenticate?(password)
    user.grant_access!(client, :scopes => scopes, :duration => 1.day)
  else
    nil
  end
end
```

The block receives the `Client` making the request, the username,
password and a `Set` of the requested scopes. It must return
`user.grant_access!(client)` if you want to allow access, otherwise it
should return `nil`.


## Using Client Credentials

If you like, OAuth lets you use client credentials to authenticate with
a provider. In this case the client application must post credentials to the
exchange endpoint. On the provider side you can handle this using the
`handle_client_credentials` and `grant_access!` API methods,
for example:

```ruby
OAuth2::Provider.handle_client_credentials do |client, owner, scopes|
  owner.grant_access!(client, :scopes => scopes, :duration => 1.day)
end
```

The block receives the `Client` making the request, the owner
 and a `Set` of the requested scopes. It must return
`owner.grant_access!(client)`

The client must be configured to support client credentials using the `is_client_credentials` in the `Client` model.


## Protecting resources with access tokens

Where a resource is protected by a token (rather than a session), we need to parse the token and validate its authenticity.  

A token may be either an Oauth2 access_token or an OpenIdConnect `id_token`.  Although, we no longer use the `access_token` as it has no cryptographic strength.  There are essentially 3 ways the token can transported:

+ As a `Bearer` token within the `AUTHORIZATION` HTTP header.  This is the recommended and default location.
+ As a `OAuth` token within the `AUTHORIZATION` HTTP header.  Dont use this anymore.
+ In a `oauth_token` query parameter.

Given this configuration, the token can be parsed using:

```ruby
Oauth2::Router.access_token_from_request(auth_params) # returns tuple [<:jwt/:access_token>, <token>]
```

The authorisation can then be obtained straight from the model (in that inimitable Rails way):

```ruby
Authorization.find_access_token(token)
```

## License

Copyright (c) 2016 Flick Electric Co.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
