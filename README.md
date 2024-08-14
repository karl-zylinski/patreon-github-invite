This is a small program that uses Patreon API to list all the members of a Patreon. It then takes those members and invites them to a GitHub organization using the GitHub API. My Patreon page uses this: https://www.patreon.com/karl_zylinski

It saves a list as a file of emails it has previously invited, so it does not do it twice (spamming GitHub with requests to invite people already invited can get you rate-limited).

It checks against the ID of two of my Patreon tiers (hard coded), see "SourceCodeTier" and "SuperTier" in the code, i.e. the lowest tier does not have source access.

My Patreon campaign ID is hard coded (see first line of get_all_emails_that_should_have_access)

Also the organization name and the User-Agent of the GitHub invite API is hard coded.

If you alter those hard coded things then you can probably use this for your own needs.

Your patreon and github API secrets go into patreon_secret.txt and github_secret.txt respectively.

I run this program as a cron job every 10 minutes on an Amazon EC2 Ubuntu Server, so it should take maximum 10 minutes for new patrons to get access.

NOTE: Currently the Patreon code does not do pagination (it will get the first 1000 members, but wont see members past this limit). I will fix this if my Patreon ever gets close to this number.
