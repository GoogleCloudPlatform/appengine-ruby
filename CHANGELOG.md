# Changelog

This is the change history for the appengine gem.

## v0.4.5 (2017-12-04)

*   Ensure tempfile is required when needed.
*   Update stackdriver dependency to 0.11.

## v0.4.4 (2017-10-03)

*   Windows compatibility for appengine:exec task. (gkaykck)

## v0.4.3 (2017-09-20)

*   Fixed incorrect namespace in the handler for gcloud errors.

## v0.4.2 (2017-09-11)

*   Fixed file permissions.

## v0.4.1 (2017-08-10)

*   Removed squiggly heredocs to regain compatibility with Ruby 2.2.

## v0.4.0 (2017-07-17)

*   Provided rake tasks to access App Engine remote execution.
*   Reimplemented AppEngine::Env as an alias to the google-cloud-env gem's
    functionality.

## v0.3.0 (2017-02-28)

*   Replaced logger integration with a dependency on the stackdriver gem,
    which supersedes it.
*   Stubbed out the env class in preparation to change it to a dependency
    on the upcoming google-cloud-env gem.

## v0.2.0 (2016-05-04)

*   Tools for integration with the Google Cloud Console logger, including
    Rack middleware and a Railtie.

## v0.1.0 (2016-04-07)

*   Initial release, reserving the appengine name. No functionality.
