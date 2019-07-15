Google App Engine Integration Tools
===================================

[![CircleCI](https://circleci.com/gh/GoogleCloudPlatform/appengine-ruby.svg?style=svg)](https://circleci.com/gh/GoogleCloudPlatform/appengine-ruby)
[![Gem Version](https://badge.fury.io/rb/appengine.svg)](https://badge.fury.io/rb/appengine)

This repository contains the "appengine" gem, a collection of libraries and
plugins for integrating Ruby apps with Google App Engine. It is not required
for deploying a ruby application to Google App Engine, but it provides a
number of convenience hooks and tools for integrating into the App Engine
environment.

Currently, it includes:

* Automatic Stackdriver instrumentation for Rails apps. This means logs,
  error reports, and latency traces are reported to the cloud console,
  and debugger integration is available.
* A client and rake tasks for executing application commands in the App
  Engine environment against production resources, useful for tasks such as
  running production database migrations.
* Convenient access to environment information such as project ID and VM
  properties.

Potential future directions:

* Tools for generating "app.yaml" configuration files for Ruby applications.
* Streamlined implementation of health checks and other lifecycle hooks.

For more information on using Google Cloud Platform to deploy Ruby apps,
please visit http://cloud.google.com/ruby

## Installation

To install, include the "appengine" gem in your Gemfile. e.g.

    gem "appengine"

## Quick Start

### Rails Quick Start

If you are running [Ruby On Rails](http://rubyonrails.org/) 4.0 or later, this
gem will automatically install a Railtie that provides its capabilities. You
may need to include the line:

    require "appengine"

in your `config/application.rb` file if you aren't already requiring all
bundled gems.

### Rack Quick Start

If you are running a different Rack-based web framework, include the following
line in your main Ruby file or `config.ru`:

    require "appengine"

Then, to activate Stackdriver instrumentation, add the following middleware:

    use Google::Cloud::Logging::Middleware
    use Google::Cloud::ErrorReporting::Middleware
    use Google::Cloud::Trace::Middleware
    use Google::Cloud::Debugger::Middleware

You can add the Rake tasks to your application by adding the following to your
Rakefile:

    require "appengine/tasks"

### Setting up appengine:exec remote execution

This gem is commonly used for its `appengine:exec` Rake task that provides a
way to run production tasks such as database migrations in the cloud. If you
are getting started with this feature, you should read the documentation
(available on the
[AppEngine::Exec module](http://www.rubydoc.info/gems/appengine/AppEngine/Exec))
carefully, for important tips. In particular:

 *  The strategy used by the gem is different depending on whether your app is
    deployed to the App Engine standard environment or flexible environment.
    It is important to understand which strategy is in use, because it affects
    which version of your application code is used to run the task, and various
    other factors.
 *  You may need to grant additional permissions to the service account that
    runs the task. Again, the documentation will describe this in detail.
 *  If your app is running on the flexible environment and uses a VPC (and
    connects to your database via a private IP address), then you will need to
    use a special configuration for the task.

## Using this library

### Logging and monitoring

This library automatically installs the "stackdriver" gem, which instruments
your application to report logs, unhandled exceptions, and latency traces to
your project's Google Cloud Console. For more information on the application
monitoring features of Google App Engine, see:

* [google-cloud-logging instrumentation](http://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-logging/latest/guides/instrumentation)
* [google-cloud-error_reporting instrumentation](http://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-error_reporting/latest/guides/instrumentation)
* [google-cloud-trace instrumentation](http://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-trace/latest/guides/instrumentation)
* [google-cloud-debugger instrumentation](http://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-debugger/latest/guides/instrumentation)

Rails applications automatically activate this instrumentation when the gem
is present. You may opt out of individual services by providing appropriate
Rails configuration. See
[AppEngine::Railtie](http://www.rubydoc.info/gems/appengine/AppEngine/Railtie)
for more information.

Non-Rails applications must provide initialization code to activate this
instrumentation, typically by installing a Rack middleware. You can find the
basic code for installing these middlewares in the Rack Quick Start section
above. See the individual service documentation links above for more
information and configuration options.

### App Engine remote execution

This library provides rake tasks for App Engine remote execution, allowing
App Engine applications to perform on-demand tasks in the App Engine
environment. This may be used for safe running of ops and maintenance tasks,
such as database migrations, that access production cloud resources. For
example, you could run a production database migration in a Rails app using:

    bundle exec rake appengine:exec -- bundle exec rake db:migrate

The migration would be run in containers on Google Cloud infrastructure, which
is much easier and safer than running the task on a local workstation and
granting that workstation direct access to your production database.

See [AppEngine::Exec](http://www.rubydoc.info/gems/appengine/AppEngine/Exec)
for more information on App Engine remote execution.

See [AppEngine::Tasks](http://www.rubydoc.info/gems/appengine/AppEngine/Tasks)
for more information on running the Rake tasks. The tasks are available
automatically in Rails applications when the gem is present. Non-Rails
applications may install the tasks by adding the line
`require "appengine/tasks"` to the `Rakefile`.

## Development and support

The source code for this gem is available on Github at
https://github.com/GoogleCloudPlatform/appengine-ruby

Report bugs on Github issues at
https://github.com/GoogleCloudPlatform/appengine-ruby/issues

Contributions are welcome. Please review the CONTRIBUTING.md file.
