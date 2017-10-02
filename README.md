Google App Engine Integration Tools
===================================

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

Planned for the near future:

* Tools for generating "app.yaml" configuration files for Ruby applications.
* Streamlined implementation of health checks and other lifecycle hooks.

For more information on using Google Cloud Platform to deploy Ruby apps,
please visit http://cloud.google.com/ruby

## Installation

To install, include the "appengine" gem in your Gemfile. e.g.

    gem "appengine"

## Rails Quick Start

If you are running [Ruby On Rails](http://rubyonrails.org/) 4.0 or later, this
gem will automatically install a Railtie that provides its capabilities. You
may need to include the line:

    require "appengine"

in your `config/application.rb` file if you aren't already requiring all
bundled gems.

## Rack Quick Start

If you are running a different Rack-based web framework, include the following
line in your main Ruby file or `config.ru`:

    require "appengine"

Then, to activate Stackdriver instrumentation, add the following middleware:

    use Google::Cloud::Logging::Middleware
    use Google::Cloud::ErrorReporting::Middleware
    use Google::Cloud::Trace::Middleware
    use Google::Cloud::Debugger::Middleware

You can add the Rake tasks to your application by adding the following to your Rakefile:

    require "appengine/tasks"

To use the Stackdriver integration you must follow the rack middleware steps for the individual gems listed below.

## Logging and monitoring

This library automatically installs the "stackdriver" gem, which instruments
your application to report logs, unhandled exceptions, and latency traces to
your project's Google Cloud Console. For more information on the application
monitoring features of Google App Engine, see:

* [google-cloud-logging instrumentation](http://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-logging/latest/guides/instrumentation)
* [google-cloud-error_reporting instrumentation](http://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-error_reporting/latest/guides/instrumentation)
* [google-cloud-trace instrumentation](http://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-trace/latest/guides/instrumentation)

Rails applications automatically activate this instrumentation when the gem
is present. You may opt out of individual services by providing appropriate
Rails configuration. See {AppEngine::Railtie} for more information.

Non-Rails applications must provide initialization code to activate this
instrumentation, typically by installing a Rack middleware. See the individual
service documentation links above for more information.

## App Engine remote execution

This library provides rake tasks for App Engine remote execution, allowing
App Engine applications to perform on-demand tasks in the App Engine
environment. This may be used for safe running of ops and maintenance tasks,
such as database migrations, that access production cloud resources. For
example, you could run a production database migration in a Rails app using:

    bundle exec rake appengine:exec -- bundle exec rake db:migrate

The migration would be run in VMs provided by Google Cloud. It uses a
privileged service account that will have access to the production cloud
resources, such as Cloud SQL instances, used by the application. This mechanism
is often much easier and safer than running the task on a local workstation and
granting that workstation direct access to those Cloud SQL instances.

See {AppEngine::Exec} for more information on App Engine remote execution.

See {AppEngine::Tasks} for more information on running the rake tasks. The
tasks are available automatically in Rails applications when the gem is
present. Non-Rails applications may install the tasks by adding the line
`require "appengine/tasks"` to the `Rakefile`.

## Development and support

The source code for this gem is available on Github at
https://github.com/GoogleCloudPlatform/appengine-ruby

Report bugs on Github issues at
https://github.com/GoogleCloudPlatform/appengine-ruby/issues

Contributions are welcome. Please review the CONTRIBUTING.md file.
