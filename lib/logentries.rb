require 'openssl'
require 'base64'
require 'digest/md5'
require 'time'


def logentries_login(le_user, le_password, request)
  # https://logentries.com/doc/webhookalert/
  #
  
  
  payload_md5 = Base64.encode64(Digest::MD5.digest(request.body.read)).strip

  @auth ||= Rack::Auth::Basic::Request.new(request.env)


  logger.info "No auth or credentials provided" if !headers.contains?('Authorization')
  return false if !headers.contains?('Authorization')
  credentials = headers['Authorization'].split(':')
  request_user = credentials[0].split(' ').last
  request_signature = credentials[1]

 #  logger.info "No auth or credentials provided" unless (@auth.provided? && @auth.credentials)
 #  return false unless (@auth.provided? && @auth.credentials)
 # 
 #  request_signature = @auth.credentials[1] 
 #  request_user = @auth.credentials[0]
 

  logger.info "request_user != le_user" if request_user != le_user
  return false unless request_user == le_user

  canonical  = [
    "POST",
    headers['Content-Type'],
    payload_md5,
    headers['Date'],
    request.path,
    headers["X-Le-Nonce"],
  ].join("n")

  dg = OpenSSL::Digest::Digest.new('sha1')
  signature = Base64.encode64(OpenSSL::HMAC.digest(dg, le_password, canonical)).strip

  logger.info "signature #{signature}"
  logger.info "request_signature signature #{request_signature}"

  (signature == request_signature)

end
