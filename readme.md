# Account Security with Voice

### ⏱ 15 min build time

## Why build voice-based account security?

Websites where users can sign up for an account typically use the email address as a unique identifier and a password as a security credential for users to sign in. At the same time, most websites ask users to add a verified phone number to their profile. Phone numbers are, in general, a better way to identify an account holder as a real person. They can also be used as a second authentication factor (2FA) or to restore access to a locked account.

Verification of a phone number is straightforward:

1. Ask your user to enter their number.
2. Call the number programmatically and use a text-to-speech system to say a security code that acts as a one-time-password (OTP).
3. Let the user enter this code on the website or inside an application as proof that they received the call.

The MessageBird Verify API assists developers in implementing this workflow into their apps. Imagine you're running a social network and want to verify your user's profiles. This MessageBird Developer Guide shows you an example of a Node.js application with integrated account security following the steps outlined above.

By the way, it is also possible to replace the second step with an SMS message, as we explain in the [two factor authentication tutorial](https://developers.messagebird.com/tutorials/verify). However, using voice for verification has the advantage that it works with every phone number, not just mobile phones, so it can be used to verify, for example, the landline of a business. The [MessageBird Verify API](https://developers.messagebird.com/docs/verify) supports both options: voice and SMS.

## Getting Started

Our sample application is built in Ruby using the [Sinatra](http://sinatrarb.com/) framework. You can download or clone the complete source code from the [MessageBird Developer Tutorials GitHub repository](https://github.com/messagebirdguides/verify-voice-guide-ruby) to run the application on your computer and follow along with the guide. To run the application, you will need [Ruby](https://www.ruby-lang.org/en/) and [bundler](https://bundler.io/) installed.

Let's now open the directory where you've stored the sample code and run the following command to install the [MessageBird SDK](https://rubygems.org/gems/messagebird-rest) and other dependencies:

```
bundle install
```

## Configuring the MessageBird SDK

The MessageBird SDK is defined in the `Gemfile`:

``` ruby
source 'http://rubygems.org'

# ...
gem 'messagebird-rest', '~> 1.4', require: 'messagebird'
# ...
```

It's loaded with a statement at the top of `app.rb`:

``` ruby
# Load and initialize MesageBird SDK
client = MessageBird::Client.new(ENV['MESSAGEBIRD_API_KEY'])
```

You need to provide a MessageBird API key via an environment variable loaded with [dotenv](https://rubygems.org/gems/dotenv). We've prepared an `env.example` file in the repository, which you should rename to `.env` and add the required information. Here's an example:

```
MESSAGEBIRD_API_KEY=YOUR-API-KEY
```

You can create or retrieve a live API key from the [API access (REST) tab](https://dashboard.messagebird.com/en/developers/access) in the _Developers_ section of your MessageBird account.

## Asking for the Phone number

The sample application contains a form to collect the user's phone number. You can see the HTML as an ERB template in the file `views/start.erb` and the route that renders it is `get '/'`. All Handlebars files use the layout stored in `views/layout.erb` to follow a common structure.

The HTML form includes a `<select>` element as a drop-down to choose the country. That allows users to enter their phone number without the country code. In production applications, you could use this to limit access on a country level and preselect the user's current country by IP address. The form field for the number is a simple `<input>` with the `type` set to `tel` to inform compatible browsers that this is an input field for telephone numbers. Finally, there's a submit button. Once the user clicks on that button, the input is sent to the `/verify` route.

## Initiating the Verification Call

When the user submits their submit, the `post '/verify'` routes takes over. The Verify API expects the user's telephone number to be in international format, so the first step is reading the input and concatenating the country code and the number. If the user enters their local number with a leading zero, we remove this digit.

``` ruby

post '/verify' do
  # Compose number from country code and number
  country_code = params[:country_code]
  phone_number = params[:phone_number][0] == '0' ? phone_number[1..-1] : params[:phone_number]
  number = "#{country_code}#{phone_number}"
```

Next, we can call `verify_create` on the MessageBird SDK. That launches the API request that initiates the verification call:

``` ruby
# Create verification request with MessageBird Verify API
client.verify_create(number,
  type: 'tts', # TTS = text-to-speech, otherwise API defaults to SMS
  template: 'Your account security code is %token.'
)
```

The method takes two parameters. The first one is the telephone number that we want to verify, and the second is a hash with configuration options. Our sample application sets two options:

* The `type` is set to `tts` to inform the API that we want to use a voice call for verification.
* The `template` contains the words to speak. It must include the placeholder `%token` so that MessageBird knows where the code goes (note that we use the words token and code interchangeably, they mean the same thing). We don't have to generate this numeric code ourselves; the API takes care of it.

There are a few other available options. For example, you can change the length of the code (it defaults to 6) with `tokenLength`. You can also specify `voice` as `male` or `female` and set the `language` to an ISO language code if you want the synthesized voice to be in a non-English language. You can find more details about these and other options in the [Verify API reference documentation](https://developers.messagebird.com/docs/verify#request-a-verify).

If there was an error, we show the same page to the user as before but add an error parameter which the template displays as a message above the form to notify the user. In the success case, we render a new template. We add the `id` attribute of the API response to this template because we need the identification of our verification request in the next step to confirm the code:

``` ruby
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
```

## Confirming the Code

The template stored in `views/verify.erb`, which we render in the success case, contains an HTML form with a hidden input field to pass forward the `id` from the verification request. It also contains a regular `<input>` with `type` set to `text` so that the user can enter the code that they've heard on the phone. When the user submits this form, it sends this token to the `/confirm` route.

Inside this route, we call another method on the MessageBird SDK, `verify_token`, and provide the ID and token as two parameters:

``` ruby
post '/confirm' do
  # Complete verification request with MessageBird Verify API
  response = client.verify_token(params[:id], params[:token])
```

Just as before, you'll need to handle any potential error states by `rescue`ing them. We inform the user about the status of the verification by showing either a new success response (which is stored in `views/confirm.erb`), or showing the first page again with an error message:

``` ruby
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
```

In production applications, you would use the success case to update your user's phone number as verified in your database.

## Testing the Application

Let's go ahead and test your application. All we need to do is enter the following command in your console:

```
ruby app.rb
```

Open your browser to http://localhost:4567/ and walk through the process yourself!

## Nice work!

You now have a running integration of MessageBird's Verify API!

You can now leverage the flow, code snippets and UI examples from this tutorial to build your own voice-based account security system. Don't forget to download the code from the [MessageBird Developer Tutorials GitHub repository](https://github.com/messagebirdguides/verify-voice-guide-ruby).

## Next steps

Want to build something similar but not quite sure how to get started? Please feel free to let us know at support@messagebird.com, we'd love to help!
