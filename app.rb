require 'dotenv'
require 'sinatra'
require 'messagebird'

set :root, File.dirname(__FILE__)

#  Load configuration from .env file
Dotenv.load if Sinatra::Base.development?

# Load and initialize MesageBird SDK
client = MessageBird::Client.new(ENV['MESSAGEBIRD_API_KEY'])

# Start of security process: capture number
get '/' do
  erb :start, locals: { error: nil }
end

post '/verify' do
  # Compose number from country code and number
  country_code = params[:country_code]
  phone_number = params[:phone_number][0] == '0' ? phone_number[1..-1] : params[:phone_number]
  number = "#{country_code}#{phone_number}"

  begin
    # Create verification request with MessageBird Verify API
    response = client.verify_create(number,
      type: 'tts', # TTS = text-to-speech, otherwise API defaults to SMS
      template: 'Your account security code is %token.'
    )
    return erb :verify, locals: { id: response.id, error: nil }
  rescue MessageBird::ErrorException => ex
    errors = ex.errors.each_with_object([]) do |error, memo|
      memo << "Error code #{error.code}: #{error.description}"
    end.join("\n")
    return erb :start, locals: { error: errors }
  end
end

post '/confirm' do
  begin
    # Complete verification request with MessageBird Verify API
    response = client.verify_token(params[:id], params[:token])
    puts response
    return erb :confirm
  rescue MessageBird::ErrorException => ex
    errors = ex.errors.each_with_object([]) do |error, memo|
      memo << "Error code #{error.code}: #{error.description}"
    end.join("\n")
    return erb :start, locals: { error: errors }
  end
end
