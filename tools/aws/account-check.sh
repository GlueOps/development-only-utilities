#!/bin/bash
##
### Variables
##
set -e

[ "$(aws sts get-caller-identity --query Account --output text)" = "$(aws organizations describe-organization --query Organization.MasterAccountId --output text)" ] && echo -e "\e[32mTHIS IS THE ROOT ACCOUNT. PLEASE PROCEED\e[0m" || echo -e "\e[31mTHIS IS NOT THE ROOT ACCOUNT STOP IMMEDIATELY.\e[0m"