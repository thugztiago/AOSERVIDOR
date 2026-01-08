#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

# ==============================
# VARIÁVEIS
# ==============================
DOMAIN="ambientesoperativos.pt"
DC1="ambientesoperativos"
DC2="pt"
IP="10.213.181.41"
HOSTNAME="srv-ambop"

LDAP_ADMIN_PASS="admin123"
USER_NAME="admin"
USER_PASS="admin"
USER_UID="10000"
GROUP_GID="5000"

# ==============================
echo "🔧 CONFIGURAÇÃO INICIAL"
# ==============================
hostnamectl set-hostname $HOSTNAME
apt update -y

# ==============================
echo "🔐 OPENLDAP"
# ==============================
echo "slapd slapd/no_configuration boolean false" | debconf-set-selections
echo "slapd slapd/domain string $DOMAIN" | debconf-set-selections
echo "slapd shared/organization string Ambientes Operativos" | debconf-set-selections
echo "slapd slapd/password1 password $LDAP_ADMIN_PASS" | debconf-set-selections
echo "slapd slapd/password2 password $LDAP_ADMIN_PASS" | debconf-set-selections

apt install slapd ldap-utils -y
systemctl enable slapd
systemctl restart slapd
sleep 3

# ==============================
echo "📁 ESTRUTURA LDAP"
# ==============================
cat > base.ldif <<EOF
dn: ou=users,dc=$DC1,dc=$DC2
objectClass: organizationalUnit
ou: users

dn: ou=groups,dc=$DC1,dc=$DC2
objectClass: organizationalUnit
ou: groups
EOF

ldapadd -x -D cn=admin,dc=$DC1,dc=$DC2 -w $LDAP_ADMIN_PASS -f base.ldif

# ==============================
echo "👥 GRUPO"
# ==============================
cat > grupo.ldif <<EOF
dn: cn=alunos,ou=groups,dc=$DC1,dc=$DC2
objectClass: posixGroup
cn: alunos
gidNumber: $GROUP_GID
EOF

ldapadd -x -D cn=admin,dc=$DC1,dc=$DC2 -w $LDAP_ADMIN_PASS -f grupo.ldif

# ==============================
echo "👤 UTILIZADOR"
# ==============================
HASH=$(slappasswd -s $USER_PASS)

cat > user.ldif <<EOF
dn: uid=$USER_NAME,ou=users,dc=$DC1,dc=$DC2
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: $USER_NAME
sn: $USER_NAME
uid: $USER_NAME
uidNumber: $USER_UID
gidNumber: $GROUP_GID
homeDirectory: /home/$USER_NAME
loginShell: /bin/bash
userPassword: $HASH
EOF

ldapadd -x -D cn=admin,dc=$DC1,dc=$DC2 -w $LDAP_ADMIN_PASS -f user.ldif

# ==============================
echo "🌐 DNS (Bind9)"
# ==============================
apt install bind9 -y

cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN" {
    type master;
    file "/etc/bind/db.$DOMAIN";
};
EOF

cat > /etc/bind/db.$DOMAIN <<EOF
\$TTL 604800
@ IN SOA $HOSTNAME.$DOMAIN. root.$DOMAIN. (
    2 604800 86400 2419200 604800 )
@ IN NS $HOSTNAME.$DOMAIN.
$HOSTNAME IN A $IP
intranet IN A $IP
EOF

systemctl restart bind9

# ==============================
echo "🌍 APACHE + PHP"
# ==============================
apt install apache2 php php-ldap -y
echo "ServerName localhost" >> /etc/apache2/apache2.conf

mkdir -p /var/www/intranet

cat > /etc/apache2/sites-available/intranet.conf <<EOF
<VirtualHost *:80>
    ServerName intranet.$DOMAIN
    DocumentRoot /var/www/intranet
</VirtualHost>
EOF

a2ensite intranet
systemctl reload apache2

# ==============================
echo "🔑 PORTAL LDAP"
# ==============================
cat > /var/www/intranet/index.php <<'EOF'
<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $ldap = ldap_connect("ldap://localhost");
    ldap_set_option($ldap, LDAP_OPT_PROTOCOL_VERSION, 3);

    $user = $_POST["user"];
    $pass = $_POST["pass"];
    $dn = "uid=$user,ou=users,dc=ambientesoperativos,dc=pt";

    if (@ldap_bind($ldap, $dn, $pass)) {
        echo "<h2>Bem-vindo, $user!</h2>";
    } else {
        echo "<p>Login inválido</p>";
    }
}
?>
<form method="post">
Utilizador: <input type="text" name="user"><br>
Password: <input type="password" name="pass"><br>
<input type="submit" value="Entrar">
</form>
EOF

chown -R www-data:www-data /var/www/intranet
chmod -R 755 /var/www/intranet

echo "✅ SERVIDOR TOTALMENTE CONFIGURADO"
