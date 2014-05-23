===================================
Heroku rollback with new relic hook
===================================

If this project isn't useful for you, use other. Don't bother me.


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

  APPS = "app1;app2;app3"  # heroku app names
  HTTP_USER = "user:SHA256passwordhashed"
  HEROKU_API_TOKEN = "asdfasdf-asdf-asdf"  # Token api from heroku with rollback available
  REDIS_URI = "REDIS://:password@host:port"  # (localhost by default)
  DEPLOY_TTL = 300  # seconds observing New Relic hook


Protected access rollback
=========================

This app require HTTP Auth Basic authentication, that is everyone who is going
to access the app is going to be asked for valid user and password. This
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
