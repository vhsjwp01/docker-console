%define __os_install_post %{nil}
%define uek %( uname -r | egrep -i uek | wc -l | awk '{print $1}' )
%define rpm_arch %( uname -p )
%define rpm_author Jason W. Plummer
%define rpm_author_email vhsjwp01@gmail.com
%define distro_id %( lsb_release -is )
%define distro_ver %( lsb_release -rs )
%define distro_major_ver %( echo "%{distro_ver}" | awk -F'.' '{print $1}' )

Summary: A simple client-server method to register docker container console access
Name: docker-console
Release: 2.8.EL%{distro_major_ver}
License: GNU
Group: Docker/Management
BuildRoot: %{_tmppath}/%{name}-root
URL: https://github.com/vhsjwp01/docker-manager
Version: 1.0
BuildArch: noarch

## These BuildRequires can be found in Base
##BuildRequires: zlib, zlib-devel 
#
## This block handles Oracle Linux UEK .vs. EL BuildRequires
#%if %{uek}
#BuildRequires: kernel-uek-devel, kernel-uek-headers
#%else
#BuildRequires: kernel-devel, kernel-headers
#%endif

# These Requires can be found in Base
Requires: gawk
Requires: nc
Requires: sed
Requires: xinetd
Requires: /usr/bin/python
Requires: coreutils

# These Requires can be found in EPEL
Requires: /usr/bin/docker

%define install_base /usr/local
%define install_bin_dir %{install_base}/bin
%define install_sbin_dir %{install_base}/sbin
%define docker_registrar_port 42001
%define docker_console_port 42002
%define docker_console_real_name docker-console
%define docker_console_registrar_real_name docker-console-registrar
%define xinetd_console_mgr_real_name docker_console_mgr
%define xinetd_registrar_mgr_real_name docker_console_registrar_mgr
%define cron_registrar_cleanup_real_name docker-registrar-cleanup
%define docker_console_daemon_real_name docker-console-mgr
%define docker_console_registrar_daemon_real_name docker-console-registrar-mgr

Source0: ~/rpmbuild/SOURCES/docker-console
Source1: ~/rpmbuild/SOURCES/docker-console-registrar
Source2: ~/rpmbuild/SOURCES/docker-console-mgr.sh
Source3: ~/rpmbuild/SOURCES/docker-console-registrar-mgr.sh
Source4: ~/rpmbuild/SOURCES/docker_console_mgr.xinetd
Source5: ~/rpmbuild/SOURCES/docker_console_registrar_mgr.xinetd
Source6: ~/rpmbuild/SOURCES/docker-registrar-cleanup.sh
Source7: ~/rpmbuild/SOURCES/docker_console.creds

%description
Docker-console is a client-server application that allows remote console
access to a running docker container.  An xinetd daemon responds to queries
passed by a client side tool called docker-console.  A separate xinetd service
registers username/password hashes and assoiates them with a container id.

%install
rm -rf %{buildroot}
# Populate %{buildroot}
mkdir -p %{buildroot}%{install_bin_dir}
cp %{SOURCE0} %{buildroot}%{install_bin_dir}/%{docker_console_real_name}
cp %{SOURCE1} %{buildroot}%{install_bin_dir}/%{docker_console_registrar_real_name}
mkdir -p %{buildroot}%{install_sbin_dir}
cp %{SOURCE2} %{buildroot}%{install_sbin_dir}/%{docker_console_daemon_real_name}
cp %{SOURCE3} %{buildroot}%{install_sbin_dir}/%{docker_console_registrar_daemon_real_name}
cp %{SOURCE6} %{buildroot}%{install_sbin_dir}/%{cron_registrar_cleanup_real_name}
mkdir -p %{buildroot}/etc/xinetd.d
cp %{SOURCE4} %{buildroot}/etc/xinetd.d/%{xinetd_console_mgr_real_name}
cp %{SOURCE5} %{buildroot}/etc/xinetd.d/%{xinetd_registrar_mgr_real_name}
cp %{SOURCE7} %{buildroot}/etc

# Build packaging manifest
rm -rf /tmp/MANIFEST.%{name}* > /dev/null 2>&1
echo '%defattr(-,root,root)' > /tmp/MANIFEST.%{name}
chown -R root:root %{buildroot} > /dev/null 2>&1
cd %{buildroot}
find . -depth -type d -exec chmod 755 {} \;
find . -depth -type f -exec chmod 644 {} \;
for i in `find . -depth -type f | sed -e 's/\ /zzqc/g'` ; do
    filename=`echo "${i}" | sed -e 's/zzqc/\ /g'`
    eval is_exe=`file "${filename}" | egrep -i "executable" | wc -l | awk '{print $1}'`
    if [ "${is_exe}" -gt 0 ]; then
        chmod 555 "${filename}"
    fi
done
find . -type f -or -type l | sed -e 's/\ /zzqc/' -e 's/^.//' -e '/^$/d' > /tmp/MANIFEST.%{name}.tmp
for i in `awk '{print $0}' /tmp/MANIFEST.%{name}.tmp` ; do
    filename=`echo "${i}" | sed -e 's/zzqc/\ /g'`
    dir=`dirname "${filename}"`
    echo "${dir}/*"
done | sort -u >> /tmp/MANIFEST.%{name}
# Clean up what we can now and allow overwrite later
rm -f /tmp/MANIFEST.%{name}.tmp
chmod 666 /tmp/MANIFEST.%{name}

%post
# Only run this on installation
if [ "${1}" = "1" ]; then
    echo "# Docker Console Registration Cleansing" >> /var/spool/cron/root
    echo "30 0 * * * ( %{install_sbin_dir}/%{cron_registrar_cleanup_real_name} 2>&1 | logger -t \"Docker Console Registration Cleansing\" )" >> /var/spool/cron/root
fi
for i in %{docker_console_daemon_real_name} %{docker_console_registrar_daemon_real_name} %{cron_registrar_cleanup_real_name} ; do
    chown root:docker %{install_sbin_dir}/${i}
    chmod 750 %{install_sbin_dir}/${i}
done
for i in %{docker_console_real_name} %{docker_console_registrar_real_name} ; do
    chown root:docker %{install_bin_dir}/${i}
    chmod 750 %{install_bin_dir}/${i}
done
let docker_console_port_check=`egrep "Simple Remote Docker Console" /etc/services | wc -l | awk '{print $1}'`
let docker_registrar_port_check=`egrep "Simple Remote Docker Registrar" /etc/services | wc -l | awk '{print $1}'`
if [ ${docker_console_port_check} -eq 0 ]; then
    echo "%{docker_console_daemon_real_name}      %{docker_console_port}/tcp               # Simple Remote Docker Console" >> /etc/services
fi
if [ ${docker_registrar_port_check} -eq 0 ]; then
    echo "%{docker_console_registrar_daemon_real_name}      %{docker_registrar_port}/tcp               # Simple Remote Docker Registrar" >> /etc/services
fi
chmod 600 /etc/docker_console.creds
chkconfig xinetd on
chkconfig %{xinetd_console_mgr_real_name} on
chkconfig %{xinetd_registrar_mgr_real_name} on
service xinetd restart > /dev/null 2>&1
service crontab restart > /dev/null 2>&1
/bin/true

%postun
# Only run this on uninstallation
if [ "${1}" = "0" ]; then
    chkconfig %{xinetd_console_mgr_real_name} off > /dev/null 2>&1
    chkconfig %{xinetd_registrar_mgr_real_name} off > /dev/null 2>&1
    sed -i -e "/Docker Console Registration Cleansing/d" /var/spool/cron/root
    let docker_console_port_check=`egrep "Simple Remote Docker Console" /etc/services | wc -l | awk '{print $1}'`
    let docker_registrar_port_check=`egrep "Simple Remote Docker Registrar" /etc/services | wc -l | awk '{print $1}'`
    if [ ${docker_console_port_check} -gt 0 ]; then
        cp -p /etc/services /tmp/services.$$
        egrep -v "Simple Remote Docker Console" /tmp/services.$$ > /etc/services
        rm -f /tmp/services.$$
    fi
    if [ ${docker_registrar_port_check} -gt 0 ]; then
        cp -p /etc/services /tmp/services.$$
        egrep -v "Simple Remote Docker Registrar" /tmp/services.$$ > /etc/services
        rm -f /tmp/services.$$
    fi
    service xinetd restart > /dev/null 2>&1
    service crontab restart > /dev/null 2>&1
fi
/bin/true

%files -f /tmp/MANIFEST.%{name}

%changelog
%define today %( date +%a" "%b" "%d" "%Y )
* %{today} %{rpm_author} <%{rpm_author_email}>
- built version %{version} for %{distro_id} %{distro_ver}

