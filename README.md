Google App Engine Integration Tools
===================================

This repository contains the "appengine" gem, a collection of libraries and
plugins for integrating Ruby apps with Google App Engine. It is not required
for deploying a ruby application to Google App Engine, but it provides a
number of convenience hooks for better integrating into the App Engine
environment.

Currently, it includes:

*   A way to configure the Logger to log to the Google Cloud Console.

For more information on using Google Cloud Platform to deploy Ruby apps,
please visit http://cloud.google.com/ruby

## Installation

To install, include the "appengine" gem in your Gemfile. e.g.

    gem "appengine"

If you are running [Ruby On Rails](http://rubyonrails.org/) 4.0 or later, this
gem will automatically install a Railtie that provides its capabilities. You
may need to include the line:

    require "appengine"

in your `config/application.rb` file if you aren't already requiring all
bundled gems. You may provide additional configuration via the
`config.appengine` object. See below for more details.

If you are using a different Rack-based framework such as
[Sinatra](http://sinatrarb.com/), you can use the provided middlewares. See
the more detailed instructions below.

## Google Cloud Console logger integration

In order for your application logs to appear in the Google Cloud Console, they
should be written in a specific format to a specific location. The logger
module in this gem provides tools to make that happen.

If you are using Ruby on Rails, and you do not otherwise customize your
Rails logger, then the provided Railtie will direct your logs to the Cloud
Console "out of the box". Normally, this is configured to take effect when
running in the `production` environment, but you may also configure it for
other environments. See the documentation for the `AppEngine::Railtie` class
for more details.

If you are running a different Rack-based framework such as Sinatra, you
should install the provided `AppEngine::Logger::Middleware` in your middleware
stack. This should be installed instead of the normal `Rack::Logger`. It will
automatically create a logger that directs entries to the Cloud Console, and
will make it available via the standard `Rack::RACK_LOGGER` key in the Rack
environment. You may also create your own logger directly using the
`AppEngine::Logger.create()` method.

## Development and support

This software is not an official Google product, and is not covered by an SLA
or support agreement. It is provided as a community-driven open source product
for the Ruby developer community, and is made available under the Apache 2.0
license.

The source code is available on Github at
https://github.com/GoogleCloudPlatform/appengine-ruby

Report bugs on Github issues at
https://github.com/GoogleCloudPlatform/appengine-ruby/issues

Contributions are welcome. Please review the CONTRIBUTING.md file.
