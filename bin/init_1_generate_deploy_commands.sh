#!/bin/bash
################################################################################
#
# A script to append deploy commands to the post boot command file at
# $PAYARA_HOME/scripts/post-boot-commands.asadmin file. All applications in the
# $DEPLOY_DIR (either files or folders) will be deployed.
# The $POSTBOOT_COMMANDS file can then be used with the start-domain using the
#  --postbootcommandfile parameter to deploy applications on startup.
#
# Usage:
# ./generate_deploy_commands.sh
#
# Optionally, any number of parameters of the asadmin deploy command can be
# specified as parameters to this script.
# E.g., to deploy applications with implicit CDI scanning disabled:
#
# ./generate_deploy_commands.sh --properties=implicitCdiEnabled=false
#
# Environment variables used:
#   - $PREBOOT_COMMANDS - the pre boot command file.
#   - $PREBOOT_COMMANDS_FINAL - copy of the pre boot command file.
#   - $POSTBOOT_COMMANDS - the post boot command file.
#   - $POSTBOOT_COMMANDS_FINAL - copy of the post boot command file.
#
# Note that many parameters to the deploy command can be safely used only when
# a single application exists in the $DEPLOY_DIR directory.
################################################################################

# Check required variables are set
if [ -z $DEPLOY_DIR ]; then echo "Variable DEPLOY_DIR is not set."; exit 1; fi

generateDeploy() {

  if [ -z $1 ]; then
    echo "No file extension provided";
    exit 1;
  fi
  test -f $DEPLOY_DIR/$1
  testext=$?
  if [ $testext -eq 0  ]
  then
   for deployment in $(ls $DEPLOY_DIR/$1)
   do
        cp -rfv $deployment  ${PAYARA_DIR}/glassfish/domains/${DOMAIN_NAME}/autodeploy;
   done
  fi

}

generatePrebootAndPosboot(){
    touch 
    cat $PREBOOT_COMMANDS > $PREBOOT_COMMANDS_FINAL
    cat $POSTBOOT_COMMANDS > $POSTBOOT_COMMANDS_FINAL
}

# RAR files first
#for deployment in $(find $DEPLOY_DIR -mindepth 1 -maxdepth 1 -name "*.rar");
#do
#  deploy $deployment;
#done

# Then every other WAR, EAR, JAR or directory
#for deployment in $(find $DEPLOY_DIR -mindepth 1 -maxdepth 1 ! -name "*.rar" -a -name "*.war" -o -name "*.ear" -o -name "*.jar" -o -type d);
#do
#  deploy $deployment;
#done
###Generate pre and pos commands
#generatePrebootAndPosboot
###Deploy rars if exists
generateDeploy *.rar
###Deploy ears if exists
generateDeploy *.ear
###Deploy wars if exists
generateDeploy *.war
###Deploy jars if exists
generateDeploy *.jar





