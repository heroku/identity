# Operations

## Cookie Encryption Key Rotation

``` bash
$ heroku config:get COOKIE_ENCRYPTION_KEY
my-really-secure-old-cookie-encryption-key

$ heroku config:set OLD_COOKIE_ENCRYPTION_KEY=my-really-secure-old-cookie-encryption-key

$ heroku config -s
COOKIE_ENCRYPTION=my-NEW-really-secure-encryption-key
OLD_COOKIE_ENCRYPTION_KEY=my-really-secure-old-cookie-encryption-key

#
# WAIT some reasonable amount of time. Probably a few days. Users need to make
# a request to Identity for their cookies ciphers to be rotated.
#

$ heroku config:remove OLD_COOKIE_ENCRYPTION_KEY
```
