#!/usr/bin/python3

import os
import shutil
import sys
from subprocess import call
from entrypoint_helpers import env, gen_cfg, gen_container_id, str2bool, start_app,  set_perms, set_ownership, activate_ssl


RUN_USER = env['run_user']
RUN_GROUP = env['run_group']
JIRA_INSTALL_DIR = env['jira_install_dir']
JIRA_HOME = env['jira_home']
SSL_ENABLED =  env.get('atl_sslenabled', False)
JIRA_SESSION_TIMEOUT = env.get('atl_session_timeout', 600)

gen_container_id()

if os.stat('/etc/container_id').st_size == 0:
    gen_cfg('container_id.j2', '/etc/container_id',
            user=RUN_USER, group=RUN_GROUP, overwrite=True)




if SSL_ENABLED == 'True' or SSL_ENABLED == True or SSL_ENABLED == 'true' :
    PATH_KEYSTORE = env.get('atl_certificate_location', '/opt/atlassian/confluence/keystore')
    PASSWORD_KEYSTORE = env.get('atl_certificate_password', "changeit")

    PATH_CERTIFICATE_KEY = env.get('atl_certificate_key_location', '/opt/atlassian/etc/certificate.key')
    PATH_CERTIFICATE = env.get('atl_certificate_location', '/opt/atlassian/etc/certificate.crt')
    PATH_CA = env.get('atl_ca_location','/opt/atlassian/etc/ca.cert')

    PATH_P12= env.get('atl_p12_location', '/opt/atlassian/etc/certificate.p12')
    PASSWORD_P12 = env.get('atl_p12_password', 'jira')

    activate_ssl( f'{JIRA_INSTALL_DIR}/atlassian-jira/WEB-INF/web.xml', PATH_KEYSTORE, PASSWORD_KEYSTORE, PATH_CERTIFICATE_KEY, PATH_CERTIFICATE, PATH_CA, PASSWORD_P12, PATH_P12)


#edit session-timeout in web.xml
call(['sed', '-i',  f's/<session-timeout>.*<\/session-timeout>/<session-timeout>{JIRA_SESSION_TIMEOUT}<\/session-timeout>/g', f'{JIRA_INSTALL_DIR}/atlassian-jira/WEB-INF/web.xml'])





try:
  set_ownership(f'{JIRA_INSTALL_DIR}/conf',  user=RUN_USER, group=RUN_GROUP)
  set_ownership(f'{JIRA_INSTALL_DIR}/logs',  user=RUN_USER, group=RUN_GROUP)
  set_ownership(f'{JIRA_INSTALL_DIR}/temp',  user=RUN_USER, group=RUN_GROUP)
  set_ownership(f'{JIRA_INSTALL_DIR}/work',  user=RUN_USER, group=RUN_GROUP)
except:
    print("Unexpected error:")

try:
  set_ownership(f'{JIRA_HOME}/import',  user=RUN_USER, group=RUN_GROUP)
  set_ownership(f'{JIRA_HOME}/export',  user=RUN_USER, group=RUN_GROUP)
  set_ownership(f'{JIRA_HOME}/log',  user=RUN_USER, group=RUN_GROUP)
  set_ownership(f'{JIRA_HOME}/plugins',  user=RUN_USER, group=RUN_GROUP)
  set_ownership(f'{JIRA_HOME}/caches',  user=RUN_USER, group=RUN_GROUP)
  set_ownership(f'{JIRA_HOME}/data/avatars',  user=RUN_USER, group=RUN_GROUP)
except:
    print("Unexpected error:")

try:
    shutil.chown(JIRA_HOME, user=RUN_USER, group=RUN_GROUP)
    shutil.chown(f'{JIRA_HOME}/data/attachments', user=RUN_USER, group=RUN_GROUP)
    shutil.chown(f'{JIRA_HOME}/data', user=RUN_USER, group=RUN_GROUP)
except:
    print("Unexpected error:")

gen_cfg('server.xml.j2', f'{JIRA_INSTALL_DIR}/conf/server.xml')

gen_cfg('dbconfig.xml.j2', f'{JIRA_HOME}/dbconfig.xml',
        user=RUN_USER, group=RUN_GROUP, overwrite=False)
if str2bool(env.get('clustered')):
    gen_cfg('cluster.properties.j2', f'{JIRA_HOME}/cluster.properties',
            user=RUN_USER, group=RUN_GROUP, overwrite=False)

start_app(f'{JIRA_INSTALL_DIR}/bin/start-jira.sh -fg', JIRA_HOME, name='Jira')