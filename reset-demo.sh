#!/bin/bash
# Réinitialise complètement la base de données avec des données de démo propres.
# À lancer juste avant une répétition ou avant la soutenance elle-même.
#
# Usage : ./reset-demo.sh
# (depuis le dossier backend/database)

set -e

MYSQL_USER="${DB_USER:-root}"
MYSQL_PASS="${DB_PASSWORD:-}"

echo "Suppression et recréation de la base eu_credit..."

if [ -z "$MYSQL_PASS" ]; then
    mysql -u "$MYSQL_USER" -e "DROP DATABASE IF EXISTS eu_credit;"
    mysql -u "$MYSQL_USER" < schema.sql
else
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "DROP DATABASE IF EXISTS eu_credit;"
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" < schema.sql
fi

echo "Base réinitialisée avec les données de démonstration."
echo "Comptes : admin@euf.cm / Admin@2026, agent@euf.cm / Agent@2026, responsable@euf.cm / Responsable@2026"
echo "Client de démo : paul.essomba@example.cm / Client@2026"
