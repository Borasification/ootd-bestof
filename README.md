# OOTD Bestof Discourse plugin

Based on François Helg's https://github.com/Borasification/fetch-ootd-posts script

## Installation

Copy the entire directory into the discourse `plugin/ootd-bestof` directory

## Configuration

In the `Admin/API` menu in Discourse, press the `New API key` button.

Write a description, select `All users` for `User level` and check the `Global key` option.

Save and make sure to backup the `api_key`.

Now in the `Admin/Settings/Plugins` menu, add the `api_key` you just created in ### `ootd bestof discourse api key`. In `ootd bestof discourse api username` put either `system` or an admin/staff level username.

Make sure `otd bestof enabled` is checked.

Now it's time to create the app on Imgur.
Open your browser and go to this URL: `https://api.imgur.com/oauth2/addclient`
Fill in the app name, then for`Authorization callback URL` enter `<discourse_instance_url>/admin/plugins/ootd-bestof/callback`

Fill in an email and a descritpion. Make sure to save the `client_id` and `client_secret` imgut gives you.

Now in the Discourse settings fill in those fields:
`ootd bestof imgur client id`
`ootd bestof imgur client secret`
with what imgur gave you.

Go to the `Admin/Plugins/OOTD Best of` menu and click the `Authenticate` button. It should open a new page on imgur asking you to login and authorize the app. Once it's done you're all setup!
