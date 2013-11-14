# Operations

## Deployment

### Preparation/Setup (only needed once, substitute your email address):

```
export HEROKU_EMAIL_ADDRESS=...
heroku sudo sharing:add $HEROKU_EMAIL_ADDRESS -a id-staging
heroku git:remote -a id-staging -r staging
heroku sudo sharing:add $HEROKU_EMAIL_ADDRESS -a id-production
heroku git:remote -a id-production -r production
```

### Process

Note: requires api-admin (install/build from http://github.com/heroku/api-admin)

```
rake test
git push staging master
api-test-login --staging
git push production master
api-test-login --production
```

## Debugging Production

### Honeybadger

Uncaught errors are sent to Honeybadger, which can be accessed via:

    heroku addons:open honeybadger -a id-staging
    heroku addons:open honeybadger -a id-production

In case of a bad API or Identity deploy and SSO is down, there is also a backdoor into the Honeybadger projects. Get credentials from LastPass.

### Logs

Identity keeps fairly detailed logs for each request:

    heroku logs --tail -n 1000 -a id-production

### Splunk

Identity's logs are also drained to the [platform Splunk installation](https://splunk.herokai.com). Identity also injects its request IDs into the Heroku API, so if the UUID of any given Identity request is obtained (i.e. find the `id=<uuid>` attribute in any emitted log line), it can used to bring up all corresponding Identity _and_ API logs in Splunk.
