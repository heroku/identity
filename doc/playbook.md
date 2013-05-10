# Playbook

## `availability`

Identity appears to be unresponsive.

Check what's going on:

    heroku logs --tail -a id-production
    heroku addons:open airbrake -a id-production

Possibly attempt a restart:

    heroku restart -a id-production
