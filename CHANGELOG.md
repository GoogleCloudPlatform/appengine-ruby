# Changelog

This is the change history for the appengine gem.

### 0.7.0 (2022-04-22)

#### Features

* add gcs log dir option
* Replace the appengine exec class with an alias to serverless-exec
* Update stackdriver dependency
#### Bug Fixes

* Fix exception when a shell command rather than a command array is given in Exec
* Fix failure in the appengine:exec cloud_build strategy when App Engine doesn't provide the image

## v0.6.0 (2020-12-02)

*   Fix failure in the appengine:exec cloud_build strategy when App Engine doesn't provide the image
*   Fix exception when appengine:exec is provided a shell command rather than a command array (tpbowden)
*   Update stackdriver dependency to 0.20 and google-cloud-env dependency to 1.4

## v0.5.0 (2019-07-15)

*   appengine:exec supports the App Engine standard environment.
*   appengine:exec supports setting the project via `GAE_PROJECT`.
*   Support for an alternate appengine:exec strategy for flexible environment apps that talk to a database via a private IP.
*   Fix crash when the gcloud path includes directories with spaces.
*   Escape `$` symbols in environment configs. (tpbowden)

## v0.4.6 (2018-09-17)

*   Use gcloud builds submit instead of gcloud container builds submit. (tbpg)
*   Update stackdriver dependency to 0.15.

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
