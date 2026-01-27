OpenVPN Pre-Logon Access Provider (PLAP) Setup
==============================================

Introduction
------------

Pre-Logon Access Provider (PLAP) is a Windows feature that allows network
connectivity to be established before a user logs into Windows. This is
particularly useful for enterprise environments where:

- Machines need to communicate with Active Directory (AD) controllers before
  user logon
- Group Policy needs to be applied during computer startup
- Domain credentials need to be verified against domain controllers
- Network authentication is required before Windows user authentication

When properly configured, OpenVPN can provide VPN connectivity in the
pre-logon state, enabling domain-joined machines to connect to the corporate
network before any user logs in.


How PLAP Works with OpenVPN
----------------------------

Windows PLAP integrates with network providers to establish connectivity
before the Windows logon screen appears. For OpenVPN, this typically involves:

1. OpenVPN runs as a Windows service (via OpenVPNServiceInteractive)
2. The VPN connection is established before user logon
3. The machine can communicate with AD and other domain services
4. Users can then authenticate using domain credentials

The OpenVPN Interactive Service (documented in ``interactive-service-notes.rst``)
is the foundation for PLAP functionality.


Configuration Approaches
-------------------------

There are several approaches to configuring OpenVPN for PLAP, each with
different trade-offs regarding automation, security, and maintainability.


Approach 1: Certificate-Based Authentication (Recommended)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Overview:**
Use certificate-based authentication instead of username/password. This
eliminates the need for password management and is the most secure and
maintainable option.

**Configuration:**

Client configuration file (``client.ovpn``)::

    client
    dev tun
    proto udp
    remote vpn.example.com 1194
    
    # Certificate-based authentication
    ca ca.crt
    cert client.crt
    key client.key
    
    # Optional: Use machine certificate from Windows Certificate Store
    # cryptoapicert "SUBJ:ComputerName"
    
    # Management interface for monitoring (optional)
    management 127.0.0.1 7505
    
    # Persistence options
    persist-key
    persist-tun
    
    # Automatically reconnect
    resolv-retry infinite
    nobind
    
    # Windows-specific options
    register-dns
    block-outside-dns

**Advantages:**

- No password management required
- Most secure option
- Easy to automate with certificate deployment tools (GPO, SCCM, Intune)
- Works seamlessly with OpenVPN Interactive Service

**Disadvantages:**

- Requires PKI infrastructure
- Certificate lifecycle management needed


Approach 2: Auth-Token with Initial Authentication
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Overview:**
Use initial username/password authentication, then rely on auth-token for
reconnections. The initial credentials can be provided via management interface
or saved in a secure location.

**Configuration:**

Client configuration file (``client.ovpn``)::

    client
    dev tun
    proto udp
    remote vpn.example.com 1194
    
    ca ca.crt
    
    # Authentication
    auth-user-pass
    
    # Management interface (for credential input)
    management 127.0.0.1 7505
    
    # Auth-token support
    # Server must push auth-token
    auth-retry interact
    
    persist-key
    persist-tun
    
    resolv-retry infinite
    nobind

**Server configuration** must push auth-token::

    # Enable auth-token (renew every 3600 seconds)
    auth-gen-token 3600

**Advantages:**

- After initial authentication, uses token for reconnections
- More secure than storing passwords
- Compatible with 2FA for initial authentication

**Disadvantages:**

- Initial authentication still required
- More complex setup


Approach 3: Automated Credential Provider
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Overview:**
Store credentials in a secured location and provide them automatically to
OpenVPN via the management interface or auth-user-pass file.

**Option 3a: Management Interface with Automated Password Provision**

Client configuration file (``client.ovpn``)::

    client
    dev tun
    proto udp
    remote vpn.example.com 1194
    
    ca ca.crt
    auth-user-pass
    
    # Management interface
    management 127.0.0.1 7505
    
    persist-key
    persist-tun

A separate credential provider application or script:

1. Retrieves credentials from secure storage (Windows Credential Manager,
   encrypted file, registry)
2. Connects to management interface on localhost:7505
3. Waits for password prompt
4. Provides credentials automatically

**Option 3b: Auth-User-Pass File (Less Secure)**

Client configuration file (``client.ovpn``)::

    client
    dev tun
    proto udp
    remote vpn.example.com 1194
    
    ca ca.crt
    
    # Credentials from file
    auth-user-pass credentials.txt
    
    persist-key
    persist-tun

Credentials file (``credentials.txt``)::

    username
    password

**Security considerations for credentials.txt:**

- File must be readable only by SYSTEM account
- Use Windows file permissions: ``icacls credentials.txt /inheritance:r /grant:r SYSTEM:F``
- Consider encrypting the file using Windows EFS or third-party tools
- Regularly rotate credentials

**Advantages:**

- Fully automated
- No user interaction required

**Disadvantages:**

- Password storage security concerns (unless properly secured)
- Credential rotation requires updating stored credentials
- Not compatible with 2FA


Management Interface Port Selection
-----------------------------------

The issue mentions concerns about ensuring the management interface port is
available. Here are several approaches:

Dynamic Port Selection
~~~~~~~~~~~~~~~~~~~~~~

Instead of hardcoding a port, use a dynamic approach:

1. **Use a consistent port range per machine:**
   Assign port numbers based on a formula, for example::

       Port = 7500 + (last octet of IP address)

2. **Use localhost binding:**
   Always bind to 127.0.0.1 (localhost) to avoid conflicts with external
   services::

       management 127.0.0.1 7505

3. **Port conflict detection:**
   Create a pre-connection script that checks if the port is available and
   modifies the configuration if needed.

Management Interface Security
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Without Password (localhost only):**

If binding only to localhost and running as SYSTEM, a password may not be
strictly necessary::

    management 127.0.0.1 7505

**With Password:**

For better security, use a management interface password::

    management 127.0.0.1 7505 /path/to/management-password.txt

The password file should contain a single line with the password and be
protected with appropriate ACLs.

**Unix Domain Socket (Alternative):**

On some systems, Unix domain sockets provide better security than TCP::

    management /var/run/openvpn/management.sock unix


Integration with Active Directory
---------------------------------

For PLAP to work effectively with Active Directory:

Network Configuration
~~~~~~~~~~~~~~~~~~~~~

1. **DNS Configuration:**
   Ensure the VPN connection properly configures DNS to point to AD controllers::

       # In client config
       register-dns
       
       # Server should push DNS
       push "dhcp-option DNS 10.0.0.1"
       push "dhcp-option DNS 10.0.0.2"
       push "dhcp-option DOMAIN example.com"

2. **Routing:**
   Ensure routes to AD infrastructure are pushed::

       # Server pushes routes to AD subnet
       push "route 10.0.0.0 255.255.255.0"

3. **Timing:**
   The VPN must be established early enough in the boot process::

       # Use Windows service with automatic start
       # OpenVPNServiceInteractive should be set to "Automatic"

Service Configuration
~~~~~~~~~~~~~~~~~~~~

1. **OpenVPN Service Setup:**
   
   The OpenVPNServiceInteractive service must be configured to start
   automatically and should have proper dependencies::

       sc config OpenVPNServiceInteractive start= auto
       sc config OpenVPNServiceInteractive depend= Dhcp/Dnscache

2. **Connection Profile Location:**
   
   Place the configuration file in the OpenVPN config directory (default:
   ``C:\Program Files\OpenVPN\config\``)

3. **Automatic Connection:**
   
   Configure OpenVPN to automatically connect on service start using the
   service wrapper.


Deployment in Enterprise Environments
-------------------------------------

Automated Configuration Deployment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For organizations using automated configuration generation:

1. **Group Policy Deployment:**
   
   - Deploy configuration files via GPO to standard location
   - Deploy certificates via GPO (if using certificate authentication)
   - Configure OpenVPN service startup via GPO

2. **Configuration Management Tools:**
   
   Use tools like SCCM, Intune, Ansible, or Puppet to:
   
   - Deploy OpenVPN client
   - Deploy configuration files
   - Configure Windows service
   - Deploy certificates or credential storage

3. **Template-Based Configuration:**
   
   Create configuration templates with placeholders::

       client
       dev tun
       proto udp
       remote vpn.example.com 1194
       
       ca ca.crt
       # Use machine certificate from Windows Certificate Store
       cryptoapicert "SUBJ:{{COMPUTERNAME}}"
       
       management 127.0.0.1 {{7500 + HOSTID}}
       
       persist-key
       persist-tun

   Replace placeholders during deployment based on machine properties.

Credential Management at Scale
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For organizations that cannot use certificate-based authentication:

1. **Windows Credential Manager:**
   
   Store credentials in Windows Credential Manager::

       cmdkey /generic:OpenVPN /user:username /pass:password

   Use a credential provider script to retrieve from Credential Manager and
   provide to OpenVPN via management interface.

2. **Azure Key Vault or Other Secret Management:**
   
   For cloud-connected environments, retrieve credentials from centralized
   secret management systems during service startup.

3. **Local Service Account:**
   
   Create a local service account specifically for OpenVPN PLAP connections,
   separate from user credentials.


Troubleshooting
---------------

Connection Not Establishing Before Logon
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1. **Check Service Status:**
   ::

       sc query OpenVPNServiceInteractive

   Ensure the service is running and set to automatic start.

2. **Check Service Dependencies:**
   ::

       sc qc OpenVPNServiceInteractive

   Verify dependencies (DHCP, DNS cache) are starting first.

3. **Review Logs:**
   
   Configure logging in the OpenVPN configuration::

       log-append "C:\\Program Files\\OpenVPN\\log\\plap.log"
       verb 4

   Check the log file for connection errors.

4. **Network Adapter Configuration:**
   
   Ensure the TAP adapter is properly configured and the Interactive Service
   has permissions to modify it.

Authentication Issues
~~~~~~~~~~~~~~~~~~~~

1. **Certificate Problems:**
   
   - Verify certificate validity: ``certutil -verify -urlfetch client.crt``
   - Check certificate store if using ``--cryptoapicert``
   - Ensure certificate chain is complete

2. **Credential Problems:**
   
   - Verify credential file permissions
   - Test credentials manually
   - Check for password policy issues (expiration, complexity)

3. **Management Interface:**
   
   - Test connection to management interface: ``telnet 127.0.0.1 7505``
   - Verify password if using management password
   - Check firewall rules (even for localhost)

DNS and Domain Connectivity Issues
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1. **DNS Not Updating:**
   ::

       ipconfig /flushdns
       ipconfig /registerdns

   Use ``--register-dns`` option in OpenVPN configuration.

2. **AD Communication:**
   
   After VPN is connected, test AD connectivity::

       nltest /dsgetdc:example.com
       ping dc1.example.com

3. **Timing Issues:**
   
   Increase connection timeout and retry settings::

       connect-timeout 60
       connect-retry-max 3


Best Practices
--------------

Security
~~~~~~~~

1. **Always use certificate-based authentication when possible**
2. **If using passwords, protect credential files with strict ACLs**
3. **Use management interface passwords when not binding to localhost only**
4. **Regularly rotate credentials and certificates**
5. **Enable ``block-outside-dns`` to prevent DNS leaks**
6. **Use ``persist-key`` and ``persist-tun`` to avoid credential re-prompting**

Reliability
~~~~~~~~~~~

1. **Configure automatic reconnection:**
   ::

       keepalive 10 60
       resolv-retry infinite

2. **Use multiple remote servers for redundancy:**
   ::

       remote vpn1.example.com 1194
       remote vpn2.example.com 1194
       remote-random

3. **Monitor connection status via management interface**
4. **Implement health checks and alerting**

Maintainability
~~~~~~~~~~~~~~

1. **Use consistent configuration templates across all machines**
2. **Centralize credential and certificate management**
3. **Document all customizations and deployment procedures**
4. **Automate deployment using configuration management tools**
5. **Implement configuration versioning and change tracking**
6. **Use descriptive naming for configuration files and certificates**


Example: Complete PLAP Setup for Active Directory
-------------------------------------------------

This example demonstrates a complete, production-ready PLAP setup for an
Active Directory environment using certificate-based authentication.

Prerequisites
~~~~~~~~~~~~~

- OpenVPN server with PKI infrastructure
- Windows clients domain-joined to AD
- Certificates deployed to machines via GPO

Client Configuration (``ad-plap.ovpn``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::

    # OpenVPN PLAP Configuration for Active Directory
    # Deploy to: C:\Program Files\OpenVPN\config\ad-plap.ovpn
    
    client
    dev tun
    proto udp
    
    # Primary and backup VPN servers
    remote vpn1.corporate.example.com 1194
    remote vpn2.corporate.example.com 1194
    remote-random
    
    # Certificate authentication using Windows Certificate Store
    ca ca.crt
    cryptoapicert "SUBJ:CN=ComputerName"
    
    # Cipher and authentication
    cipher AES-256-GCM
    auth SHA256
    
    # Management interface for monitoring
    management 127.0.0.1 7505
    
    # Connection reliability
    resolv-retry infinite
    nobind
    persist-key
    persist-tun
    keepalive 10 60
    
    # Windows-specific options
    register-dns
    block-outside-dns
    
    # Logging
    log-append "C:\\Program Files\\OpenVPN\\log\\ad-plap.log"
    verb 3
    
    # Compression (optional, based on server config)
    compress lz4-v2

Service Configuration Script
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

PowerShell script to configure the OpenVPN service for PLAP (``setup-plap.ps1``)::

    # Run as Administrator
    
    # Ensure OpenVPN is installed
    $openvpnPath = "C:\Program Files\OpenVPN"
    if (-not (Test-Path $openvpnPath)) {
        Write-Error "OpenVPN not found at $openvpnPath"
        exit 1
    }
    
    # Configure service to start automatically
    Set-Service -Name "OpenVPNServiceInteractive" -StartupType Automatic
    
    # Set service dependencies
    sc.exe config OpenVPNServiceInteractive depend= Dhcp/Dnscache
    
    # Create log directory
    $logDir = "$openvpnPath\log"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    
    # Set permissions on log directory
    $acl = Get-Acl $logDir
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl $logDir $acl
    
    # Start the service
    Start-Service -Name "OpenVPNServiceInteractive"
    
    Write-Host "PLAP configuration completed successfully"

Verification
~~~~~~~~~~~~

After deployment, verify PLAP functionality:

1. **Restart the computer without logging in**
2. **At the Windows logon screen, open Task Manager (Ctrl+Shift+Esc)**
3. **Check that openvpn.exe process is running**
4. **Attempt domain logon - credentials should be verified against AD**
5. **Check log file** (``C:\Program Files\OpenVPN\log\ad-plap.log``) for
   connection status


References
----------

- ``interactive-service-notes.rst`` - OpenVPN Interactive Service documentation
- ``gui-notes.txt`` - OpenVPN GUI and echo command documentation
- ``management-notes.txt`` - Management interface documentation
- ``windows-options.rst`` - Windows-specific OpenVPN options

For more information about Windows credential providers and PLAP, refer to
Microsoft documentation on Pre-Logon Access Provider implementation.


Conclusion
----------

Setting up OpenVPN for PLAP in an enterprise environment requires careful
consideration of authentication methods, credential management, and service
configuration. Certificate-based authentication is strongly recommended for
security and maintainability. When properly configured, OpenVPN PLAP provides
seamless pre-logon VPN connectivity for domain-joined Windows machines,
enabling proper Active Directory integration and Group Policy application.

For automated deployment at scale, use configuration management tools and
follow the best practices outlined in this document to minimize administrative
overhead while maintaining security.
