require 'openssl'
require 'base64'
require 'digest/md5'
require 'time'


def logentries_login(le_user, le_password, request)
  # https://logentries.com/doc/webhookalert/
  #
  payload_md5 = Base64.encode64(Digest::MD5.digest(request.body.read)).strip
  request.body.rewind

  headers = request.env

  logger.info "---header---"
  logger.info "#{headers}"
  logger.info "---body---"
  logger.info "#{request.body.read}"
  logger.info "------"

  logger.info "No auth or credentials provided" unless headers.include?('HTTP_AUTHORIZATION')
  return false unless headers.include?('HTTP_AUTHORIZATION')

  credentials = headers['HTTP_AUTHORIZATION'].split(':')
  request_user = credentials[0].split(' ').last
  request_signature = credentials[1]

  logger.info "request_user != le_user" if request_user != le_user
  return false unless request_user == le_user

  canonical  = [
    "POST",
    headers['HTTP_CONTENT_TYPE'],
    payload_md5,
    headers['HTTP_DATE'],
    request.path,
    headers["HTTP_X_LE_NOUNCE"],
  ].join("n")

  dg = OpenSSL::Digest::Digest.new('sha1')
  signature = Base64.encode64(OpenSSL::HMAC.digest(dg, le_password, canonical)).strip

  logger.info "signature #{signature}"
  logger.info "request_signature signature #{request_signature}"

  (signature == request_signature)

end
