# identity

Based on the concept of web-based Heroku user management not belonging in the API over the long-term, Identity pulls session-based authentication out of API and provides a drop-in replacement for the Heroku OAuth API that consumers can use instead.

OAuth session management is achieved without any special API permissions by being implemented as a "meta-OAuth" provider. Identity first authorizes itself to get access to a user's account, then authorizes other consumers that use it as a target by proxying calls to the API (but using only the JSON authentication APIs).

## Usage

``` bash
bundle install
foreman start
# check localhost:5000
```

Platform deployment instructions to follow.

## Test

``` bash
bin/test
```

## Project Status

Implemented:

* Login
* OAuth provider APIs
* Reset password start (i.e. enter an e-mail)
* Reset password finish (i.e. enter a new password)
* Signup start (i.e. enter an e-mail)

To do:

* Signup finish (i.e. enter a password) -- need to reskin the existing version
* Signup "slug" logic
* 404 + 500 pages
* Platform deployment instructions
