require 'spec_helper'

describe OAuth2::Model::Client do
  before do
    @client = OAuth2::Model::Client.create(:name => 'App', :redirect_uri => 'http://example.com/cb')
    @owner  = Factory(:owner)
    OAuth2::Model::Authorization.for(@owner, @client)
  end

  it "is valid" do
    expect(@client).to be_valid
  end

  it "is invalid without a name" do
    @client.name = nil
    expect(@client).to_not be_valid
  end

  it "is invalid without a redirect_uri" do
    @client.redirect_uri = nil
    expect(@client).to_not be_valid
  end

  it "is invalid with a non-URI redirect_uri" do
    @client.redirect_uri = 'foo'
    expect(@client).to_not be_valid
  end

  # http://en.wikipedia.org/wiki/HTTP_response_splitting
  it "is invalid if the URI contains HTTP line breaks" do
    @client.redirect_uri = "http://example.com/c\r\nb"
    expect(@client).to_not be_valid
  end

  if (defined?(ActiveRecord::VERSION) && ActiveRecord::VERSION::MAJOR <= 3) || defined?(ProtectedAttributes)
    it "cannot mass-assign client_id" do
      @client.update_attributes(:client_id => 'foo')
      expect(@client.client_id).to_not == 'foo'
    end

    it "cannot mass-assign client_secret" do
      @client.update_attributes(:client_secret => 'foo')
      expect(@client.client_secret).to_not == 'foo'
    end
  end

  it "has client_id and client_secret filled in" do
    expect(@client.client_id).to_not be_nil
    expect(@client.client_secret).to_not be_nil
  end

  it "destroys its authorizations on destroy" do
    @client.destroy
    expect(OAuth2::Model::Authorization.count).to be_zero
  end

  describe "valid_client_secret?" do
    it "is not valid with bad secret" do
      expect(@client.valid_client_secret?("junk")).to be false
    end

    it "is not valid with good secret" do
      @client.client_secret = "good_secret"
      expect(@client.valid_client_secret?("good_secret")).to be true
    end

    context "native app" do
      it "is always valid" do
        @client.client_type = OAuth2::NATIVE_APP
        expect(@client.valid_client_secret?("junk")).to be true
      end
    end
  end
end

