# BlacklightEds

## Installation

Add this line to your application's Gemfile:

Note: the gem is currently in a private repository. You'll need to get a authentication token and use the token
in the git string. Follow the instructions here to get a token: [https://gist.github.com/masonforest/4048732]

TODO: Change this instruction once the repository is public

```ruby
gem 'blacklight_eds', git: 'https://your_token:x-oauth-basic@github.com/ebsco/blacklight_eds_gem.git'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install blacklight_eds

## Usage

For now, you need to manually edit some files in your blacklight app for the gem to work. We'll develop generators to take care
of most of the manual steps.

TODO: Update this section once tasks are implemented to automate the setup

* Add the following to `blacklight/app/controllers/application_controller.rb`

```ruby
require 'ebsco-discovery-service-api'
```

```ruby
helper BlacklightEds::Engine.helpers
```

* Use session store. If your blacklight app is still using cookie_store, update it to using session store.

In `blacklight/Gemfile`, add a line

```ruby
gem 'activerecord-session_store'
```

Then run

```ruby
bundle install
```

From command line,

```
rails generate active_record:session_migration
```

Then in `blacklight/config/initializers/session_store.rb`, change

```ruby
(App)::Application.config.session_store :active_record_store, :key => 'xxx'
```

to

```ruby
(App)::Application.config.session_store :active_record_store
```

* Add EDS profile

Create a file `blacklight/config/eds.yml`, add the following:

```
defaults: &DEFAULTS
  default:
    username: your_eds_username
    password: your_eds_password
    profile: your_eds_profile

  other:
    ...

development:
  <<: *DEFAULTS

test:
  <<: *DEFAULTS

production:
  <<: *DEFAULTS

```

* Add intializer

* Configure routes

In `blacklight/config/routes.rb`, add a line

```ruby
mount BlacklightEds::Engine, at: "eds"
```

This will mount the blacklight_eds gem to the url `[blacklight_root_url]/eds/articles`


TODO: Update the config file after make the gem support multiple profiles

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/blacklight_eds/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
