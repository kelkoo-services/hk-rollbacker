require 'openssl'
require 'base64'
require 'digest/md5'
require 'time'
require 'uri'
require 'json'

def get_request_le_signature(path, body, headers, le_password)
  payload_md5 = Base64.encode64(Digest::MD5.digest(body)).strip
  canonical  = [
    "POST",
    headers['HTTP_CONTENT_TYPE'],
    payload_md5,
    headers['HTTP_DATE'],
    path,
    headers["HTTP_X_LE_NOUNCE"],
  ].join("n")

  dg = OpenSSL::Digest::Digest.new('sha1')
  Base64.encode64(OpenSSL::HMAC.digest(dg, le_password, canonical)).strip
end


def logentries_login(le_user, le_password, request)
  # https://logentries.com/doc/webhookalert/
  #
  body = request.body.read
  request.body.rewind

  headers = request.env

  body_decoded = URI::Escape.decode(body)

  logger.info "---header---"
  logger.info "#{headers}"
  logger.info "---body---"
  logger.info "#{body_decoded}"
  logger.info "------"

  logger.info "No auth or credentials provided" unless headers.include?('HTTP_AUTHORIZATION')
  return false unless headers.include?('HTTP_AUTHORIZATION')

  credentials = headers['HTTP_AUTHORIZATION'].split(':')
  request_user = credentials[0].split(' ').last
  request_signature = credentials[1]

  logger.info "request_user != le_user" if request_user != le_user
  return false unless request_user == le_user

  signature = get_request_le_signature(request.path, body, request.env, le_password)
  signature_decoded = get_request_le_signature(request.path, body_decoded, request.env, le_password)

  logger.info "signature #{signature}"
  logger.info "signature_decoded #{signature_decoded}"
  logger.info "request_signature #{request_signature}"

  (signature == request_signature)

end
