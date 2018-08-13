#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

# 					# You must invoke this from the scripts directory
VAR=`dirname $0`			# Obtain the scripts directory name
cd $VAR/..				# Change to its parent which should be ZOWE_ROOT_DIR
ZOWE_ROOT_DIR=`pwd`			# Set our environment variable
#echo ZOWE_ROOT_DIR = $ZOWE_ROOT_DIR
if [[ ! -d $ZOWE_ROOT_DIR/explorer-server ]]
then
	echo You must run this script from the ZOWE_ROOT_DIR/scripts directory
	echo You are running from $VAR
	exit 1
fi
echo Start ZOWE server
$ZOWE_ROOT_DIR/scripts/internal/opercmd "S ZOWESVR,SRVRPATH='"$ZOWE_ROOT_DIR"/explorer-server'"
echo Start command issued, check SDSF job log ...
