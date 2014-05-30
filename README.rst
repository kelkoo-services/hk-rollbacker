=======================================
Heroku rollback with New Relic web hook
=======================================

Heroku suggest to do rollback manually, but if want to be unsafe you can use my
rollbacker app.

You can find the New Relic Web Hooks doc in this link:

https://docs.newrelic.com/docs/alerts/webhook-examples


Deployment
==========

Run bundle to install requirements

.. code-block:: bash

   bundle install

You can launch the service with foreman or with directly with ruby:

.. code-block:: bash

   bundle exec ruby app.rb

Run bundle to install requirements

Setup
=====

This app read the required variables from environment

.. code-block:: bash

  APPS="app1;app2;app3"  # heroku app names
  HTTP_USER="user:SHA256passwordhashed"
  HEROKU_API_TOKEN="a base64 hash"
  REDIS_URI="REDIS://:password@host:port"  # (localhost by default)
  DEPLOY_TTL=300  # seconds waiting for New Relic hook
  MANUAL_ROLLBACK=true # Set this if you only want email alert without rollback
  EMAIL_ENABLED=true  # Set this if you want to receive an email with rollbacks


The email setup allow to use mailgun settings in Heroku and the follow
environment variables:

.. code-block::

  EMAIL_HOST     # default: '127.0.0.1'
  EMAIL_PORT     # default:  25
  EMAIL_USER     # default: false to connect without authetincation
  EMAIL_PASSWORD
  EMAIL_FROM     # default: rollbacker@generic-rollback.com
  EMAIL_SUBJECT_PREFIX # default to '[ROLLBACKER]'
  EMAIL_ALLWAYS_CC # default: false


The mailgun accepted variables are:

.. code-block::

  MAILGUN_SMTP_SERVER
  MAILGUN_SMTP_SERVER
  MAILGUN_SMTP_LOGIN
  MAILGUN_SMTP_PASSWORD


The **HEROKU_API_TOKEN** var is the base64 hash of join email and the API TOKEN
you can get from Heroku in your account settings.

If you are in Linux or OSX you can get the hash with the follow line

.. code-block::

  echo -n "{email}{API TOKEN}" | base64


Protected access rollback
=========================

This app require HTTP Auth Basic authentication. This mean is everyone who is
going to access the app is going to be asked for valid user and password. This
include the New Relic Hook and the developer hook.

This credential is setted by environment.

The password is a hexdigest of sha256. You can get it with:

If you are in GNU based OS (linux):

.. code-block::

  echo -n 'yourpassword' | sha256sum

If you are in OSX:

.. code-block::

  echo -n 'youpassword' | shasum -a 256


Then, we need to add a user:

.. code-block::

  export HTTP_USER='youruser:yourpasswordhash'


Available Hooks
===============


New Deployment
--------------

This action enables the monitoring during the TTL set time.

The resource path is /APP_IN_APPS/newrelease/

This accept json POST with this structure:

.. code-block:: javascript

   {
    email:'the-user-email'
   }


Rollback
--------

This action call to heroku to do a rollback if the **newrelease** hook was
called before during the set TTL.

The resource path is /APP_IN_APPS/rollback/

This accept json POST with the New Relic json schema.
