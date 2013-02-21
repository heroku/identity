# Identity Production Checklist

* [ ] Set up a high-fidelity staging replica.
* [ ] Add to the [platform lifecycle board](https://trello.com/board/platform-engineering-life-cycle/504fbaecbc351ac46c476027)
* [ ] Request an audit by the security team - this may be backlogged or handled immediatly.
* [ ] Has a Readme that explains how to run the app locally and create a personal platform deploy.
* [ ] Has operational docs that provide executable instructions for common operational tasks.
* [ ] Alerts a human if it is down.
* [ ] Has its code on Github in the Heroku organization.
* [ ] Has undergone simulation testing to ensure graceful handling of degredation and failure modes.
* [ ] Uses [structured logging](https://github.com/heroku/engineering-docs/blob/master/logs-as-data.md).
* [ ] Minimizes external service dependencies (e.g. using an existing Postgres database instead of Redis for OpenId).
* [ ] Enforces SSL access (redirects all http: over to https:).
* [ ] Consider adding the app to the credroll list on the
  [employee exit checklist](https://docs.google.com/a/heroku.com/spreadsheet/ccc?key=0AqLn4J8Q7We2dGR6LVFhVHNjNjlPRkxZRE4tLTlDTnc#gid=0).
* [ ] Follows our [availability best practices](https://devcenter.heroku.com/articles/maximizing-availability) with [heroku-production-check](https://github.com/heroku/heroku-production-check).
* [ ] Does not depend on any development-level add-ons.
* [ ] Does not have an unused add-ons installed.
* [ ] Has an `ERROR_PAGE_URL` (if a web app).
* [ ] Has a `MAINTENANCE_PAGE_URL` (if a web app).
* [ ] Has been reviewed for [OWASP top-10 app vulnerabilities](https://www.owasp.org/index.php/Top_10_2010-Main).
* [ ] Is owned by a Heroku Manager org.
* [ ] Shows a suitable error page when encountering an internal error.
* [ ] Has proper credentials (e.g. is not using your personal API key)
* [ ] Drains app logs somewhere (e.g. splunk)
