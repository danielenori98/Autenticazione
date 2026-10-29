@echo off
setlocal

REM ===== Configurazione LDAP =====
set NAME=ldap-test
set DOMAIN=example.com
set BASE_DN=dc=example,dc=com
set ADMIN_DN=cn=admin,%BASE_DN%
set ADMIN_PW=admin
set LDIF=%TEMP%\user.ldif

REM ===== Configurazione Keycloak =====
set KC_NAME=keycloak-test
set KC_ADMIN=admin
set KC_PW=admin
set KC_REALM=myrealm
set KC_CLIENT=myclient
set KC_USER=user
set KC_USER_PW=user
set KC_CLIENT_SECRET=mysecret

REM ===== Avvia il container OpenLDAP =====
echo.
echo Avvio del container %NAME%...
docker run -d --name %NAME% -p 389:389 -p 636:636 -e LDAP_ORGANISATION="Example" -e LDAP_DOMAIN="%DOMAIN%" -e LDAP_ADMIN_PASSWORD="%ADMIN_PW%" osixia/openldap:1.5.0
if errorlevel 1 goto :errore

REM ===== Avvia il container Keycloak (Modalita Dev) =====
echo Avvio del container %KC_NAME%...
docker run -d --name %KC_NAME% -p 8080:8080 -e KC_BOOTSTRAP_ADMIN_USERNAME=%KC_ADMIN% -e KC_BOOTSTRAP_ADMIN_PASSWORD=%KC_PW% quay.io/keycloak/keycloak:26.1.0 start-dev
if errorlevel 1 goto :errore

REM ===== Attende che LDAP sia pronto =====
echo.
echo Attendo che il server LDAP sia pronto...
set /a TRIES=0
:wait_ldap
docker exec %NAME% ldapsearch -x -H ldap://localhost -b %BASE_DN% -D "%ADMIN_DN%" -w %ADMIN_PW% >nul 2>&1
if not errorlevel 1 goto :ready_ldap
set /a TRIES+=1
if %TRIES% geq 30 goto :timeout
timeout /t 2 >nul
goto :wait_ldap

:ready_ldap
REM ===== Crea e inserisce l'utente LDAP =====
echo Creazione utente su LDAP...
echo dn: ou=users,%BASE_DN%>%LDIF%
echo objectClass: organizationalUnit>>%LDIF%
echo ou: users>>%LDIF%
echo.>>%LDIF%
echo dn: uid=user,ou=users,%BASE_DN%>>%LDIF%
echo objectClass: inetOrgPerson>>%LDIF%
echo objectClass: posixAccount>>%LDIF%
echo uid: user>>%LDIF%
echo cn: user>>%LDIF%
echo sn: user>>%LDIF%
echo givenName: user>>%LDIF%
echo mail: user@%DOMAIN%>>%LDIF%
echo uidNumber: 10000>>%LDIF%
echo gidNumber: 10000>>%LDIF%
echo homeDirectory: /home/user>>%LDIF%
echo userPassword: user>>%LDIF%

docker cp %LDIF% %NAME%:/tmp/user.ldif
docker exec %NAME% ldapadd -x -H ldap://localhost -D "%ADMIN_DN%" -w %ADMIN_PW% -f /tmp/user.ldif >nul 2>&1
del %LDIF% >nul 2>&1

REM ===== Attende che Keycloak sia pronto =====
echo.
echo Attendo che il server Keycloak sia pronto...
set /a TRIES=0
:wait_kc
docker exec %KC_NAME% /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user %KC_ADMIN% --password %KC_PW% >nul 2>&1
if not errorlevel 1 goto :ready_kc
set /a TRIES+=1
if %TRIES% geq 30 goto :timeout
timeout /t 3 >nul
goto :wait_kc

:ready_kc
echo Popolamento Keycloak in corso...
REM 1. Crea il Realm
docker exec %KC_NAME% /opt/keycloak/bin/kcadm.sh create realms -s realm=%KC_REALM% -s enabled=true >nul 2>&1

REM 2. Crea il Client iniettando il JSON con il Secret fisso
echo {"clientId": "%KC_CLIENT%", "publicClient": false, "secret": "%KC_CLIENT_SECRET%", "directAccessGrantsEnabled": true, "enabled": true}>%TEMP%\kc_client.json
docker cp %TEMP%\kc_client.json %KC_NAME%:/tmp/kc_client.json
docker exec %KC_NAME% /opt/keycloak/bin/kcadm.sh create clients -r %KC_REALM% -f /tmp/kc_client.json >nul 2>&1
del %TEMP%\kc_client.json >nul 2>&1

REM 3. Crea l'utente e imposta la password permanente
docker exec %KC_NAME% /opt/keycloak/bin/kcadm.sh create users -r %KC_REALM% -s username=%KC_USER% -s enabled=true -s emailVerified=true -s email=%KC_USER%@%DOMAIN% -s firstName=%KC_USER% -s lastName=%KC_USER%
docker exec %KC_NAME% /opt/keycloak/bin/kcadm.sh set-password -r %KC_REALM% --username %KC_USER% --new-password %KC_USER_PW%

REM ===== Riepilogo e verifiche finali =====
echo.
echo ========================================================
echo  AMBIENTE DI TEST CONFIGURATO CON SUCCESSO
echo ========================================================
echo  [LDAP] pronto su ldap://localhost:389
echo    - Utente  : uid=user,ou=users,%BASE_DN% (Pass: user)
echo.
echo  [KEYCLOAK] pronto su http://localhost:8080
echo    - Console : Admin / Admin
echo    - Realm   : %KC_REALM%  ^|  Client ID: %KC_CLIENT%
echo    - Utente  : %KC_USER% (Pass: %KC_USER_PW%)
echo ========================================================
goto :fine

:timeout
echo Timeout: Uno dei server non e' diventato disponibile in tempo.
pause
exit /b 1

:errore
echo Si e' verificato un errore durante l'avvio dei container.
pause
exit /b 1

:fine
pause
endlocal