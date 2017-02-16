Google App Engine Integration Tools
===================================

This repository contains the "appengine" gem, a collection of libraries and
plugins for integrating Ruby apps with Google App Engine. It is not required
for deploying a ruby application to Google App Engine, but it provides a
number of convenience hooks for better integrating into the App Engine
environment.

Currently, it includes:

* Automatic Stackdriver instrumentation for Rails apps. This means logs,
  error reports, and latency traces are reported to the cloud console.
* A placeholder for a class that provides app engine environment information
  such as project ID and VM info.

Planned for the near future:

* Streamlined implementation of health checks and other lifecycle hooks.

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
bundled gems.

## Logging and monitoring

This library automatically installs the "stackdriver" gem, which instruments
your application to report logs, unhandled exceptions, and latency traces to
your project's Google Cloud Console. For more information on the application
monitoring features of Google App Engine, see:

* [google-cloud-logging instrumentation](http://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-logging/latest/guides/instrumentation)
* [google-cloud-error_reporting instrumentation](http://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-error_reporting/latest/guides/instrumentation)
* [google-cloud-trace instrumentation](http://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-trace/latest/guides/instrumentation)

## Development and support

The source code for this gem is available on Github at
https://github.com/GoogleCloudPlatform/appengine-ruby

Report bugs on Github issues at
https://github.com/GoogleCloudPlatform/appengine-ruby/issues

Contributions are welcome. Please review the CONTRIBUTING.md file.
