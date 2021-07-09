import sys
import os
import shutil
import logging
import jinja2 as j2
import uuid
import base64
import xml.etree.ElementTree as ET
import subprocess
from subprocess import call

logging.basicConfig(level=logging.DEBUG)


######################################################################
# Setup inputs and outputs

# Import all ATL_* and Dockerfile environment variables. We lower-case
# these for compatability with Ansible template convention. We also
# support CATALINA variables from older versions of the Docker images
# for backwards compatability, if the new version is not set.
env = {k.lower(): v
       for k, v in os.environ.items()}


# Setup Jinja2 for templating
jenv = j2.Environment(
    loader=j2.FileSystemLoader('/opt/atlassian/etc/'),
    autoescape=j2.select_autoescape(['xml']))


######################################################################
# Utils

def set_perms(path, user, group, mode):
    shutil.chown(path, user=user, group=group)
    os.chmod(path, mode)
    for dirpath, dirnames, filenames in os.walk(path):
        shutil.chown(dirpath, user=user, group=group)
        os.chmod(dirpath, mode)
        for filename in filenames:
            shutil.chown(os.path.join(dirpath, filename), user=user, group=group)
            os.chmod(os.path.join(dirpath, filename), mode)


def set_ownership(path, user, group):
    shutil.chown(path, user=user, group=group)
    for dirpath, dirnames, filenames in os.walk(path):
        shutil.chown(dirpath, user=user, group=group)
        for filename in filenames:
            shutil.chown(os.path.join(dirpath, filename), user=user, group=group)

def check_perms(path, uid, gid, mode):
    stat = os.stat(path)
    return all([
        stat.st_uid == int(uid),
        stat.st_gid == int(gid),
        stat.st_mode & mode == mode
    ])

def gen_cfg(tmpl, target, user='root', group='root', mode=0o644, overwrite=True):
    if not overwrite and os.path.exists(target):
        logging.info(f"{target} exists; skipping.")
        return

    logging.info(f"Generating {target} from template {tmpl}")
    cfg = jenv.get_template(tmpl).render(env)
    try:
        with open(target, 'w') as fd:
            fd.write(cfg)
    except (OSError, PermissionError):
        logging.warning(f"Container not started as root. Bootstrapping skipped for '{target}'")
    else:
        set_perms(target, user, group, mode)

def gen_container_id():
    env['uuid'] = uuid.uuid4().hex
    with open('/etc/container_id') as fd:
        lcid = fd.read()
        if lcid != '':
            env['local_container_id'] = lcid

def str2bool(v):
    if str(v).lower() in ('yes', 'true', 't', 'y', '1'):
        return True
    return False


def activate_ssl(web_path, path_keystore, password_keystore, path_key, path_crt, path_ca, password_p12, path_p12):
    if  os.path.exists(web_path):
        ET.register_namespace('', "http://java.sun.com/xml/ns/javaee")
        ET.register_namespace('xsi', "http://www.w3.org/2001/XMLSchema-instance")
        tree = ET.parse(web_path)
        root = tree.getroot()

        new_security_constraint =  ET.SubElement(root, 'security-constraint')
        web_resource_collection = ET.SubElement(new_security_constraint, 'web-resource-collection')
        user_data_constraint = ET.SubElement(new_security_constraint, 'user-data-constraint')


        web_resource_name = ET.SubElement(web_resource_collection, 'web-resource-name')
        url_pattern = ET.SubElement(web_resource_collection, 'url-pattern')
        url_pattern1 = ET.SubElement(web_resource_collection, 'url-pattern')
        url_pattern2 = ET.SubElement(web_resource_collection, 'url-pattern')
        url_pattern3 = ET.SubElement(web_resource_collection, 'url-pattern')

        transport_guarantee = ET.SubElement(user_data_constraint, 'transport-guarantee')

        web_resource_name.text = "all-except-attachments"
        url_pattern.text = "*.jsp"
        url_pattern1.text = "*.jspa"
        url_pattern2.text = "/browse/*"
        url_pattern3.text = "/issues/*"
        transport_guarantee.text = "CONFIDENTIAL"

        tree.write(web_path)

def unset_secure_vars():
    secure_keywords = ('PASS', 'SECRET', 'TOKEN')
    for key in os.environ:
        if any(kw in key.upper() for kw in secure_keywords):
            logging.warning(f"Unsetting environment var {key}")
            del os.environ[key]
######################################################################
# Start App as the correct user


def check_permissions(home_dir):
    """Ensure the home directory is set to minimal permissions"""
    if str2bool(env.get('set_permissions') or True) and check_perms(home_dir, env['run_uid'], env['run_gid'], 0o700) is False:
        set_perms(home_dir, env['run_user'], env['run_group'], 0o700)
        logging.info(f"User is currently root. Will change directory ownership and downgrade run user to {env['run_user']}")
    else:
        logging.info(f"User is currently root. Will downgrade run user to {env['run_user']}")

def exec_app(start_cmd_v, home_dir, name='app', env_cleanup=False):
    """Run the supplied application startup command.

    Arguments:
    start_cmd -- A list of the command and its arguments.
    home_dir -- Application home directory.
    name -- (Optional) The name to display in the log message.
    env_cleanup -- (Default: False) Remove possibly sensitive env-vars.
    """
    if os.getuid() == 0:
        check_permissions(home_dir)
        cmd = '/bin/su'
        args = [cmd, env['run_user'], '-c', " ".join(start_cmd_v)]
    else:
        cmd = start_cmd_v[0]
        args = start_cmd_v

    if env_cleanup:
        unset_secure_vars()

    logging.info(f"Running {name} with command '{cmd}', arguments {args}")
    os.execv(cmd, args)


def start_app(start_cmd, home_dir, name='app', env_cleanup=False):
    """Run the supplied application startup command.

    DEPRECATED: This function uses a nested shell, which can #
    interfere with signal handling and clean shutdown.

    Arguments:
    start_cmd -- A single string with the command and arguments.
    home_dir -- Application home directory.
    name -- (Optional) The name to display in the log message.
    env_cleanup -- (Default: False) Remove possibly sensitive env-vars.
    """
    if os.getuid() == 0:
        check_permissions(home_dir)
        cmd = '/bin/su'
        args = [cmd, env['run_user'], '-c', start_cmd]
    else:
        cmd = '/bin/sh'
        args = [cmd, '-c', start_cmd]

    if env_cleanup:
        unset_secure_vars()

    logging.info(f"Running {name} with command '{cmd}', arguments {args}")
    os.execv(cmd, args)
