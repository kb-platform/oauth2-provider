require 'active_record'

module OAuth2
  module Model
    autoload :Helpers,       ROOT + '/oauth2/model/helpers'
    autoload :ClientOwner,   ROOT + '/oauth2/model/client_owner'
    autoload :ResourceOwner, ROOT + '/oauth2/model/resource_owner'
    autoload :Hashing,       ROOT + '/oauth2/model/hashing'
    autoload :Authorization, ROOT + '/oauth2/model/authorization'
    autoload :Client,        ROOT + '/oauth2/model/client'

    Schema = OAuth2::Schema

    def self.duplicate_record_error?(error)
      error.class.name == 'ActiveRecord::RecordNotUnique'
    end

    # This will only return an authorisation for JWT and non-JWT tokens
    # TODO: Refactor this to an access token service (probably exchange)
    def self.find_access_token(token_tuple)
      return nil if token_tuple.nil?
      return nil if Provider.token_decoder.nil? || !Provider.token_decoder[0].respond_to?(Provider.token_decoder[1])
      if token_tuple[0] == :jwt
        begin
          Authorization.find_by_jwt(Provider.token_decoder[0].send(Provider.token_decoder[1], token_tuple[1]))
        rescue JSON::JWT::Exception => e
          nil
        end
      else
        Authorization.find_by_access_token_hash(Lib::SecureCodeScheme.hashify(token_tuple[1]))
      end
    end
  end
end
