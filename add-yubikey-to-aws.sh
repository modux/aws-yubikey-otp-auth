#!/bin/bash
# Adds a Yubikey TOTP device to IAM


read -p "Please type the AWS Profile name: " -r
PROFILE=$REPLY
unset REPLY

if grep -qi microsoft /proc/version; then
    # wsl
    YKMAN_EXE=ykman.exe
else
    YKMAN_EXE=ykman
fi


ACCOUNT_ARN=$(aws sts get-caller-identity --profile "$PROFILE"-auth --query Arn --output text)

# Assume that the final portion of the ARN is the username
# Works for ARNs like `users/<user>` and `users/engineers/<user>`
USERNAME=$(echo "$ACCOUNT_ARN" | rev | cut -d/ -f1 | rev)

echo $USERNAME

OUTFILE=$(mktemp)
trap 'rm -f "$OUTFILE"' EXIT

SERIAL_NUMBER=$(aws iam create-virtual-mfa-device \
    --virtual-mfa-device-name "$USERNAME" \
    --profile "$PROFILE"-auth \
    --bootstrap-method Base32StringSeed \
    --outfile "$OUTFILE" \
    --query VirtualMFADevice.SerialNumber \
--output text)

${YKMAN_EXE} oath accounts add -f "$SERIAL_NUMBER" < "$OUTFILE" 2> /dev/null

CODE1=$(${YKMAN_EXE} oath code -s "$SERIAL_NUMBER" | tr -d '\r\n')

WAIT_TIME=$((30-$(date +%s)%30))
echo "Waiting $WAIT_TIME seconds before generating a second code" >&2
sleep $WAIT_TIME

CODE2=$(${YKMAN_EXE} oath code -s "$SERIAL_NUMBER" | tr -d '\r\n')

echo $CODE1
echo $CODE2

aws iam enable-mfa-device --user-name "${USERNAME}" --serial-number "${SERIAL_NUMBER}" --authentication-code1 "${CODE1}" --authentication-code2 "${CODE2}" --profile "${PROFILE}-auth"
