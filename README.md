# identity

Based on the concept of web-based Heroku user management not belonging in the API over the long-term, Identity pulls session-based authentication out of API and provides a drop-in replacement for the Heroku OAuth API that OAuth clients can use instead.

OAuth session management is achieved without any special API permissions by a "meta-OAuth" provider implementation. Identity first authorizes itself to get access to a user's account, then authorizes other consumers that use it as a target by proxying calls to the API (but using only the JSON authentication APIs).

## Operations

See [operations](https://github.com/heroku/identity/tree/master/operations.md).

## Usage

``` bash
bundle install
cp .env.sample .env # And then edit it
foreman start
# check localhost:5000
```

## Platform Install

```
heroku config:add COOKIE_ENCRYPTION_KEY=...
heroku config:add DASHBOARD_URL="https://dashboard.heroku.com"
heroku config:add HEROKU_API_URL="https://api.heroku.com"
heroku config:add HEROKU_OAUTH_ID=...
heroku config:add HEROKU_OAUTH_SECRET=...
git push heroku master
```

## Deploying

### Preperation/Setup (only needed once, substitute your email address):

```
export HEROKU_EMAIL_ADDRESS=...
heroku sudo sharing:add $HEROKU_EMAIL_ADDRESS -a id-staging
heroku git:remote -a id-staging -r staging
heroku sudo sharing:add $HEROKU_EMAIL_ADDRESS -a id-production
heroku git:remote -a id-production -r production
```

### Deployment

```
foreman run bin/test
git push staging master
api-test-login --staging
git push production master
api-test-login --production
```

## Debugging Production

### Airbrake

Uncaught errors are sent to Airbrake, which can be accessed via:

    heroku addons:open airbrake -a id-production

_Note that this command itself requires that Identity be functional. @todo: provide a direct API request that can be executed to get the Airbrake SSO URL in case of an emergency._

### Logs

Identity keeps fairly detailed logs for each request:

    heroku logs --tail -n 1000 -a id-production

### Splunk

Identity's logs are also drained to the [platform Splunk installation](https://splunk.herokai.com). Identity also injects its request IDs into the Heroku API, so if the UUID of any given Identity request is obtained (i.e. find the `id=<uuid>` attribute in any emitted log line), it can used to bring up all corresponding Identity _and_ API logs in Splunk.

## Test

``` bash
bin/test
```

## Installations

* `id-production`: https://id.heroku.com
    * Powered by `api.heroku.com`
    * Mirrored by:
        * `id-production-eu`: ~~https://id.heroku.com~~ (not activated yet)
    * Consumed by **kernel** apps:
       * `core`: https://api.heroku.com
    * Consumed by **platform** apps:
        * `addons`: https://addons.heroku.com
        * `addons-staging`: https://addons.herokuapp.com
        * `cloner-staging`: https://cloner-staging.herokuapp.com
        * `cloner-production`: https://cloner.heroku.com
        * `dashboard`: https://dashboard.heroku.com
        * `dashboard-brandur`: https://dashboard-brandur.herokuapp.com
        * `dashboard-dev`: https://dashboard-dev.heroku.com
        * `dashboard-staging`: https://dashboard-dev.heroku.com
        * `dataclips`: https://dataclips.heroku.com
        * `dataclips-staging`: https://dataclips-staging.herokuapp.com/
        * `devcenter-eu`: https://devcenter.heroku.com
        * `devcenter-metrics`: https://devcenter-metrics.heroku.com
        * `devcenter-staging`: https://devcenter-staging.heroku.com
        * `help`: https://help.heroku.com
        * `help-staging`: https://help-staging.heroku.com
        * `manager`: https://manager.heroku.com
        * `manager-dev`: https://manager-dev.herokuapp.com
        * `manager-sandbox`: https://manager-sandbox.herokuapp.com
        * `manager-staging`: https://manager-staging.herokuapp.com
        * `oauth-example`: https://oauth-example.herokuapp.com
        * `postgres`: https://postgres.heroku.com
        * `postgres-staging`: https://postgres-staging.herokuapp.com/
        * `redeem-production`: https://redeem.heroku.com DONE
        * `redeem-staging`: https://redeem-staging.heroku.com
        * `vault`: https://vault.heroku.com
        * `vault-staging`: https://vault-staging.herokuapp.com
* `id-staging`: https://id-staging.herokuapp.com
    * Powered by `api.staging.herokudev.com`
    * Consumed by **kernel** apps:
       * `core`: https://api.staging.herokudev.com
    * Consumed by **platform** apps:
        * `dashboard-api-staging`: https://dashboard-api-staging.herokuapp.com
        * `oauth-example-staging`: https://oauth-example-staging.herokuapp.com
