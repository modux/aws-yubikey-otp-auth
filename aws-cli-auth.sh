#!/bin/bash
#
# Sample for getting temp session token from AWS STS
#
# aws --profile youriamuser sts get-session-token --duration 3600 \
# --serial-number arn:aws:iam::012345678901:mfa/user --token-code 012345
#
# Once the temp token is obtained, you'll need to feed the following environment
# variables to the aws-cli:
#

if grep -qi microsoft /proc/version; then
    # wsl
    YKMAN_EXE=ykman.exe
else
    YKMAN_EXE=ykman
fi

AWS_CLI=`which aws`
DURATION=3600 # 900 = 15 minutes | 3600 = 1 hour | 86400 = 24 hours


if [ $? -ne 0 ]; then
    echo "AWS CLI is not installed; exiting"
    exit 1
else
    echo "Using AWS CLI found at $AWS_CLI"
fi

# 1 or 2 args ok
if [[ $# -ne 1  ]]; then
    echo "Usage: $0 <MFA_TOKEN_CODE> <AWS_CLI_PROFILE>"
    echo "Where:"
    # echo "   <MFA_TOKEN_CODE> = Code from virtual MFA device"
    echo "   <AWS_CLI_PROFILE> = aws-cli profile usually in $HOME/.aws/config"
    exit 2
fi

AWS_CLI_PROFILE=${1:-default}

YUBIKEY=$(${YKMAN_EXE} list --serials | grep -oh "[[:digit:]]*")
# MFA_TOKEN_CODE=$1
AWS_USER=$(aws iam get-user  --profile "$AWS_CLI_PROFILE"-auth --output text --query 'User.UserName')
ARN_OF_MFA=$(aws iam list-mfa-devices --user-name $AWS_USER  --profile "$AWS_CLI_PROFILE"-auth --output text --query 'MFADevices[*].SerialNumber' | grep -oh arn:aws:iam::[0-9]*:mfa/[a-z\-]*)

echo Touch YubiKey
MFA_TOKEN_CODE=$(${YKMAN_EXE} --device $YUBIKEY oath accounts code $ARN_OF_MFA | grep -oh "\s[[:digit:]]*" | xargs)
echo $MFA_TOKEN_CODE

echo Adding profile "AWS-CLI Profile: $AWS_CLI_PROFILE"
echo "MFA ARN: $ARN_OF_MFA"

# read AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN <<< \
CREDS=$( aws --profile "$AWS_CLI_PROFILE"-auth sts get-session-token \
    --serial-number $ARN_OF_MFA \
    --token-code "${MFA_TOKEN_CODE}" \
    --output text \
--duration-seconds $DURATION )

set -- $CREDS


if [ -z "$5" ];
then
    exit
fi



aws configure set --profile "$AWS_CLI_PROFILE"  aws_access_key_id "$2"

aws configure set --profile "$AWS_CLI_PROFILE"  aws_secret_access_key "$4"

# write the security token ( required for ansible aws_security_token )
aws configure set --profile "$AWS_CLI_PROFILE" aws_session_token "$5"

# replace or insert aws_security token

AWS_LINE=$( grep -n -A 1 -B1  "$5" ~/.aws/credentials | grep security_token | grep -oh ^[0-9]* || echo 0)

if [ "$AWS_LINE" -gt 1 ];
then
    sed -i "${AWS_LINE}s:aws_security_token.*:aws_security_token = $5:g" ~/.aws/credentials
    
else
    sed -i "s:aws_session_token.*$5:aws_security_token = $5:g" ~/.aws/credentials
    # write the aws_session_token
    aws configure set --profile "$AWS_CLI_PROFILE" aws_session_token "$5"
    
fi

# Echo how many hours the token is valid for
echo Token valid for $(expr $DURATION / 60 / 60) hours

export AWS_DEFAULT_PROFILE="$AWS_CLI_PROFILE"
