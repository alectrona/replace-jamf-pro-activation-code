# Replace Jamf Pro Activation Code

A tool designed for CI/CD pipelines that automates the changing of Activation Codes in Jamf Pro servers.

### Environmental Variables

The below Environmental Variables are required.

* JAMF_PRO_ACTIVATION_CODE
* JAMF_PRO_API_USER

Of course, this assumes you are using the same Activation Code and API username to perform this action on each server. If that is not the case, you can easily modify the code to pass these into the script as arguments.

### How to Run

Once you've set up your environmental variables above, you can simply run the script by passing your Jamf Pro API password as argument 1 and your Jamf Pro server as argument 2.

``` sh
bash scripts/replace-jamf-pro-activation-code.sh \
    "$JSS_API_PASS" \
    "https://YOUR_SERVER.jamfcloud.com"
```

Although you can run this locally, it is designed to be easily ran in your CI/CD platform. View a [sample pipeline configuration file for Bitbucket](bitbucket-pipelines.yml).

### Required Permissions

The Jamf Pro user account used with this tool must have the below permissions.
| Jamf Pro Server Settings | Read | Update |
| ---------- | ----  | ------ |
| Activation Code	| ✓ | ✓ |
