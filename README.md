# AWS CLI & EKS Yubikey Authentication

Bash scripts to authenticate to AWS profiles using Yubikey

Scripts can also be used to authenticate to AWS EKS with a Yubikey providing the OTP MFA code.

## Requirements
Yubikey manager installed and accessible in Linux or Windows.

This is a bash script so will work in WSL or native Linux

 - ./ykman on Linux
 - ykman.exe on WSL

## Usage

````
./add-yubikey-to-aws.sh [profile-name]
````
This will add a Yubikey MFA stick to an AWS account that doesn't yet have it.

 - The account name will need to be suffixed with *-auth

````
./aws-cli-auth.sh [profile-name]
````

This will look for an entry in ~/.aws/credentials titled [profile-name]-auth

It will authenticate and to AWS CLI using your assigned Yubikey OTP oath slot.

````
./aws-eks-auth.sh [profile-name]
````

This will look for an entry in ~/.aws/credentials titled [profile-name]-auth

It will authenticate and to AWS and also add the credentials into your kubectl authentication configuration.
