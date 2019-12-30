#!/usr/bin/python3

import os

from entrypoint_helpers import env, gen_cfg, gen_container_id, str2bool, start_app


RUN_USER = env['run_user']
RUN_GROUP = env['run_group']
JIRA_INSTALL_DIR = env['jira_install_dir']
JIRA_HOME = env['jira_home']
SSL_ENABLED =  env.get('atl_sslenabled', False)

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
    PASSWORD_P12 = env.get('atl_p12_password', 'confluence')

    activate_ssl( f'{JIRA_INSTALL_DIR}/confluence/WEB-INF/web.xml', PATH_KEYSTORE, PASSWORD_KEYSTORE, PATH_CERTIFICATE_KEY, PATH_CERTIFICATE, PATH_CA, PASSWORD_P12, PATH_P12)


gen_cfg('server.xml.j2', f'{JIRA_INSTALL_DIR}/conf/server.xml')

gen_cfg('dbconfig.xml.j2', f'{JIRA_HOME}/dbconfig.xml',
        user=RUN_USER, group=RUN_GROUP, overwrite=False)
if str2bool(env.get('clustered')):
    gen_cfg('cluster.properties.j2', f'{JIRA_HOME}/cluster.properties',
            user=RUN_USER, group=RUN_GROUP, overwrite=False)

start_app(f'{JIRA_INSTALL_DIR}/bin/start-jira.sh -fg', JIRA_HOME, name='Jira')