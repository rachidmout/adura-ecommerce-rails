Rails.application.config.filter_parameters += %i[
  passw email token secret crypt salt certificate otp ssn cvv cvc authorization http_authorization higgsfield_credentials
]
