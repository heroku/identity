# identity

Based on the concept of web-based Heroku user management not belonging in the API over the long-term, Identity pulls session-based authentication out of API and provides a drop-in replacement for the Heroku OAuth API that OAuth clients can use instead.

OAuth session management is achieved without any special API permissions by a "meta-OAuth" provider implementation. Identity first authorizes itself to get access to a user's account, then authorizes other consumers that use it as a target by proxying calls to the API (but using only the JSON authentication APIs).

## Usage

``` bash
bundle install
foreman start
# check localhost:5000
```

## Platform Install

```
# should be the running domain of your app for cookies to work
heroku config:add COOKIE_DOMAIN="id.heroku.com" # domain of your app
heroku config:add COOKIE_ENCRYPTION_KEY=...
heroku config:add DASHBOARD_URL="https://dashboard.heroku.com"
heroku config:add HEROKU_API_URL="https://api.heroku.com"
heroku config:add HEROKU_COOKIE_DOMAIN="heroku.com" # domain where consumers live
heroku config:add HEROKU_OAUTH_ID=...
heroku config:add HEROKU_OAUTH_SECRET=...
git push heroku master
```

## Test

``` bash
bin/test
```

### Installations

* `id-production`: https://id.heroku.com
* `id-staging`: https://id-staging.herokuapp.com
