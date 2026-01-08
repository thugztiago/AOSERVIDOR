#!/bin/bash

# ==============================
# CONFIGURAÇÃO LDAP
# ==============================
DC1="ambientesoperativos"
DC2="pt"
BASE_DN="dc=$DC1,dc=$DC2"
USERS_OU="ou=users,$BASE_DN"
LDAP_ADMIN="cn=admin,$BASE_DN"

DEFAULT_GID="5000"   # grupo alunos

# ==============================
# INPUT DO UTILIZADOR
# ==============================
read -p "Novo utilizador (uid): " USER

read -s -p "Password: " PASS1
echo
read -s -p "Confirmar password: " PASS2
echo

if [ "$PASS1" != "$PASS2" ]; then
    echo "❌ As passwords não coincidem"
    exit 1
fi

read -s -p "Password do admin LDAP: " LDAP_ADMIN_PASS
echo

# ==============================
# GERAR UID AUTOMÁTICO
# ==============================
LAST_UID=$(ldapsearch -x -LLL -b "$BASE_DN" "(uidNumber=*)" uidNumber \
  | awk '/uidNumber:/ {print $2}' \
  | sort -n \
  | tail -1)

if [ -z "$LAST_UID" ]; then
    UID_NUMBER=10000
else
    UID_NUMBER=$((LAST_UID + 1))
fi

# ==============================
# CRIAR PASSWORD HASH
# ==============================
HASH=$(slappasswd -s "$PASS1")

# ==============================
# CRIAR LDIF
# ==============================
cat > novo_user.ldif <<EOF
dn: uid=$USER,$USERS_OU
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: $USER
sn: $USER
uid: $USER
uidNumber: $UID_NUMBER
gidNumber: $DEFAULT_GID
homeDirectory: /home/$USER
loginShell: /bin/bash
userPassword: $HASH
EOF

# ==============================
echo "👤 A criar utilizador LDAP $USER (UID $UID_NUMBER)..."
# ==============================

ldapadd -x \
  -D "$LDAP_ADMIN" \
  -w "$LDAP_ADMIN_PASS" \
  -f novo_user.ldif

if [ $? -eq 0 ]; then
    echo "✅ Utilizador criado com sucesso!"
else
    echo "❌ Erro ao criar utilizador"
fi

rm -f novo_user.ldif
