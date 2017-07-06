# Changelog

This is the change history for the appengine gem.

## v0.4.0 (2017-07-??)

*   Provided rake tasks to access App Engine remote execution.
*   Implemented AppEngine::Env as an alias to the google-cloud-env gem's
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
