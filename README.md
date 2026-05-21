# Salesforce June/July 2026, MFA Requirement
Starting in June and July 2026, Salesforce will require MFA (multi factor authentication) for all user interface based logins to Salesforce orgs. This applies to both production and sandbox orgs. 

The MFA needs to be strong i.e. email and sms is not enough and needs to be signaled by the IdP (identity provider) if SSO (single sign on) is used. The signalling should be done using the industry standard `amr` or `acr` claims for either OpenID Connect or SAML. If not signalled the user will be prompted for MFA at Salesforce i.e. it is important that your IdP signals this correctly.

Furthermore for admin / priviledged users Salesforce will require **phishing-resistant MFA** i.e. physical security keys, platform authenticators (such as Touch ID, Windows Hello etc) and passkeys. Priviledged users are users with the `System Administrator` profile *OR* one of the following permissions through a permission set or a permission set group: 
* `Modify All Data`
* `View All Data`
* `Customize Application`
* `Author Apex` 

To find the priviledged users you may use the script in this repo. The script use the Salesforce CLI (`sf`) to find and list the users. 

There is no MFA requirement for integration users classified as users not logging in through the user interface i.e. using some kind of headless OAuth flow (`JWT Bearer`, `client_credentials` etc.).

## Requirements
* An already authenticated connection to the org to query (use `sf org login web`)
* Salesforce CLI installed
* `jq` installed

## Example output
```bash
$ ./find-privileged-users.sh
Enter the org alias to query: wt_oslo

Querying for privileged users in org: wt_oslo

Finding users with System Administrator profile...
Finding permission sets with elevated permissions...
Finding permission set groups containing those permission sets...
Finding users assigned to elevated permission sets...
Finding users assigned to elevated permission set groups...
Fetching user details...

┌────────────────────┬───────────────────────────┬─────────────────────────────────────────────┐
│ ID                 │ NAME                      │ EMAIL                                       │
├────────────────────┼───────────────────────────┼─────────────────────────────────────────────┤
│ 005J9000001Z5xPIAS │ Mikkel Flindt Heisterberg │ foobar@example.com                          │
│ 005J90000022p4tIAA │ Platform Integration User │ noreply@00dj9000002fhswma0                  │
└────────────────────┴───────────────────────────┴─────────────────────────────────────────────┘

Total number of records retrieved: 2.
Querying Data... done
```