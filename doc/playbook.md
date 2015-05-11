# Playbook

## `availability`

Identity appears to be unresponsive.

Check what's going on:

    heroku logs --tail -a id-production
    https://rollbar.com/Heroku-3/identity/

Possibly attempt a restart:

    heroku restart -a id-production
