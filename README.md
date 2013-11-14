# identity

Based on the concept of web-based Heroku user management not belonging in the API over the long-term, Identity pulls session-based authentication out of API and provides a drop-in replacement for the Heroku OAuth API that OAuth clients can use instead.

OAuth session management is achieved by a "meta-OAuth" provider implementation. Identity first authorizes itself to get access to a user's account, then authorizes other consumers that use it as a target by proxying calls to the API (but using only the JSON authentication APIs). The one caveat here is that Identity must have the `can_manage_authorizations` flag set for it in API.

## Issue and Security Vulnerability Reporting

In general Heroku makes extensive use of GitHub issues, and for the
vast majority of bugs we encourage reporters to use them here.  For
the limited case of exploitable security vulnerabilities, we ask
researchers to report problems to security@heroku.com.
[We also have general reporting guidelines, which list the security team's PGP key](https://www.heroku.com/policy/security#vuln_report).

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

Your OAuth client will also need to be able to manage authorizations, which is set by an internal flag.

## Test

``` bash
rake test
```
