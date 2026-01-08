#!/bin/bash

# ==============================
# CONFIGURAÇÃO LDAP
# ==============================
DC1="ambientesoperativos"
DC2="pt"
LDAP_ADMIN="cn=admin,dc=$DC1,dc=$DC2"

read -s -p "Password do admin LDAP: " LDAP_ADMIN_PASS
echo

read -p "Utilizador LDAP (uid): " USER
read -s -p "Nova password: " NEW_PASS
echo
read -s -p "Confirmar nova password: " CONFIRM_PASS
echo

if [ "$NEW_PASS" != "$CONFIRM_PASS" ]; then
    echo "❌ As passwords não coincidem"
    exit 1
fi

USER_DN="uid=$USER,ou=users,dc=$DC1,dc=$DC2"

# ==============================
echo "🔐 A alterar password do utilizador $USER..."
# ==============================

ldappasswd -x \
    -D "$LDAP_ADMIN" \
    -w "$LDAP_ADMIN_PASS" \
    -s "$NEW_PASS" \
    "$USER_DN"

if [ $? -eq 0 ]; then
    echo "✅ Password alterada com sucesso!"
else
    echo "❌ Erro ao alterar a password"
fi
