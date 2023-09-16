#!/bin/bash

apiPass="$1"
jamfProURL="${2%/}"
newActivationCodeXML="<activation_code><code>$JAMF_PRO_ACTIVATION_CODE</code></activation_code>"
unset apiToken existingJSON existingActivationCode newJSON changeActivationCodeResult
 
# Expire the token when done
function finish() {

    # Expire the Bearer Token
    [[ -n "$apiToken" ]] && curl -s -H "Authorization: Bearer $apiToken" "${jamfProURL}/uapi/auth/invalidateToken" -X POST
}
trap "finish" EXIT

# Function to get a Jamf Pro API Bearer Token
function get_jamf_pro_api_token() {
    local healthCheckHttpCode validityHttpCode

    # Make sure we can contact the Jamf Pro server
    healthCheckHttpCode=$(curl -s "$jamfProURL/healthCheck.html" -X GET -o /dev/null -w "%{http_code}")
    [[ "$healthCheckHttpCode" != "200" ]] && echo "Unable to contact the Jamf Pro server; exiting" && exit 5

    # Attempt to obtain the token
    apiToken=$(curl -s -u "$JAMF_PRO_API_USER:$apiPass" "$jamfProURL/api/v1/auth/token" -X POST 2>/dev/null | jq -r '.token | select(.!=null)')
    [[ -z "$apiToken" ]] && echo "Unable to obtain a Jamf Pro API Bearer Token; exiting" && exit 6

    # Validate the token
    validityHttpCode=$(curl -s -H "Authorization: Bearer $apiToken" "${jamfProURL}/api/v1/auth" -X GET -o /dev/null -w "%{http_code}")
    parse_jamf_pro_api_http_codes "$validityHttpCode" || exit 7

    return
}

# Function to parse Jamf Pro API http codes
# https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview#response-codes
function parse_jamf_pro_api_http_codes() {
    local httpCode="$1"

    case "$httpCode" in
        200) # Request successful.
            return
            ;;
        201) # Request to create or update resource successful.
            return
            ;;
        202) # The request was accepted for processing, but the processing has not completed.
            return
            ;;
        204) # Request successful. Resource successfully deleted.
            return
            ;;
        # Anything past this point is an error and will return 1
        400)
            echo "Bad request. Verify the syntax of the request, specifically the request body."
            ;;
        401)
            echo "Authentication failed. Verify the credentials being used for the request."
            ;;
        403)
            echo "Invalid permissions. Verify the account being used has the proper permissions for the resource you are trying to access."
            ;;
        404)
            echo "Resource not found. Verify the URL path is correct."
            ;;
        409)
            echo "The request could not be completed due to a conflict with the current state of the resource."
            ;;
        412)
            echo "Precondition failed. See error description for additional details."
            ;;
        414)
            echo "Request-URI too long."
            ;;
        500)
            echo "Internal server error. Retry the request or contact support if the error persists."
            ;;
        503)
            echo "Service unavailable."
            ;;
        *)
            echo "Unknown error occured ($httpCode)."
            ;;
    esac

    return 1
}

# Exit if our arguments are not set
[[ -z "$JAMF_PRO_ACTIVATION_CODE" ]] && echo "JAMF_PRO_ACTIVATION_CODE is not set; exiting." && exit 1
[[ -z "$JAMF_PRO_API_USER" ]] && echo "JAMF_API_USER is not set; exiting." && exit 2
[[ -z "$apiPass" ]] && echo "apiPass is not set; exiting." && exit 3

# Exit if jq is not installed
if ! command -v jq > /dev/null ; then
    echo "Error: jq is not installed, can't continue."
    exit 4
fi

# Get our Jamf Pro API Bearer Token
get_jamf_pro_api_token

# Get the existing Activation Code JSON object
existingJSON=$(curl -sf -H "Authorization: Bearer $apiToken" \
    "${jamfProURL}/JSSResource/activationcode" -H "accept: application/json")

# Parse out the existing Activation Code
existingActivationCode=$(echo "$existingJSON" | jq -r '.activation_code.code | select(.!=null)')

# Error if we could not obtain the existing code
if [[ -z "$existingActivationCode" ]]; then
    echo "Error: Failed to obtain the current Activation Code; exiting."
    exit 8
fi

# Exit if the codes match
if [[ "$existingActivationCode" == "$JAMF_PRO_ACTIVATION_CODE" ]]; then
    echo "Existing Activation Code matches new Activation Code; exiting."
    exit 0
fi

# Attempt to update the Activation Code and grab the http code
changeActivationCodeResult=$(curl -sf -H "Authorization: Bearer $apiToken" "${jamfProURL}/JSSResource/activationcode" \
    -H "Content-Type: text/xml" -d "$newActivationCodeXML" -X PUT -o /dev/null -w "%{http_code}")

# Ensure the request was successful
if ! parse_jamf_pro_api_http_codes "$changeActivationCodeResult"; then
    echo "Error: Failed to update the Jamf Pro Activation Code."
    exit 9
fi

echo "Successfully updated the Jamf Pro Activation Code to:"
echo "$JAMF_PRO_ACTIVATION_CODE"

exit 0