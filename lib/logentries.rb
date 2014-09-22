require 'openssl'
require 'base64'
require 'digest/md5'
require 'time'


def logentries_login(le_user, le_password, request)
  # https://logentries.com/doc/webhookalert/
  #
  
  
  payload_md5 = Base64.encode64(Digest::MD5.digest(request.body.read)).strip

  @auth ||= Rack::Auth::Basic::Request.new(request.env)

  return false unless @auth.provided? && @auth.credentials 
 
  request_signature = @auth.credentials[1] 
  request_user = @auth.credentials[0]

  return false unless request_user == le_user

  canonical  = [
    "POST",
    headers['Content-Type'],
    payload_md5,
    headers['Date'],
    path,
    headers["X-Le-Nonce"],
  ].join("n")

  dg = OpenSSL::Digest::Digest.new('sha1')
  signature = Base64.encode64(OpenSSL::HMAC.digest(dg, le_password, canonical)).strip

  (signature == request_signature)

end
