-- ============================================================
-- Migration : Espace client (auto-inscription + preuves légales)
-- À exécuter sur une base eu_credit déjà créée avec schema.sql
-- ============================================================
USE eu_credit;

-- Le client peut désormais se créer un compte lui-même (email + mot de passe)
ALTER TABLE clients
    ADD COLUMN email               VARCHAR(150)  NULL UNIQUE AFTER prenom,
    ADD COLUMN mot_de_passe        VARCHAR(255)  NULL AFTER email,
    ADD COLUMN statut_verification ENUM('en_attente','verifie','rejete') NOT NULL DEFAULT 'en_attente' AFTER revenu_mensuel,
    ADD COLUMN cree_via            ENUM('agent','auto_inscription') NOT NULL DEFAULT 'agent' AFTER statut_verification;

-- Les clients déjà enregistrés par un agent (données de démo) sont
-- considérés vérifiés par défaut, puisqu'un agent les a déjà saisis.
UPDATE clients SET statut_verification = 'verifie' WHERE cree_via = 'agent';

-- ============================================================
-- TABLE : documents_clients
-- Pièces justificatives (preuves légales / KYC) associées à un client
-- ============================================================
CREATE TABLE IF NOT EXISTS documents_clients (
    id                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    client_id           INT UNSIGNED    NOT NULL,
    type_document       ENUM('cni','justificatif_revenu','justificatif_domicile','autre') NOT NULL,
    nom_original        VARCHAR(255)    NOT NULL,
    chemin_fichier      VARCHAR(255)    NOT NULL,
    statut              ENUM('en_attente','valide','rejete') NOT NULL DEFAULT 'en_attente',
    commentaire         VARCHAR(255)    NULL,
    verifie_par         INT UNSIGNED    NULL,
    uploaded_at         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    verified_at         TIMESTAMP       NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (client_id)   REFERENCES clients(id)      ON DELETE CASCADE,
    FOREIGN KEY (verifie_par) REFERENCES utilisateurs(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE INDEX idx_documents_client ON documents_clients(client_id);
CREATE INDEX idx_documents_statut ON documents_clients(statut);

-- Un client de démonstration qui s'est auto-inscrit depuis l'espace client,
-- en attente de vérification de ses documents par un agent
-- (mot de passe de démo : Client@2026)
INSERT INTO clients (nom, prenom, email, mot_de_passe, telephone, adresse, profession,
                      revenu_mensuel, statut_verification, cree_via) VALUES
('Essomba', 'Paul', 'paul.essomba@example.cm',
 '$2a$10$2ZXhMxioZo4Z8f/ShTwGM.Y.yoHp01/c4cvOUO.PkO.csWIfKIOM6',
 '694556677', 'Nkolbisson, Yaoundé', 'Menuisier', 275000, 'en_attente', 'auto_inscription');

-- Documents de démonstration pour ce client (fichiers placeholder à copier
-- dans backend/uploads/documents/ — voir le README de la migration)
INSERT INTO documents_clients (client_id, type_document, nom_original, chemin_fichier, statut)
SELECT id, 'cni', 'cni_paul_essomba.txt', 'demo_cni_paul_essomba.txt', 'en_attente'
FROM clients WHERE email = 'paul.essomba@example.cm';

INSERT INTO documents_clients (client_id, type_document, nom_original, chemin_fichier, statut)
SELECT id, 'justificatif_revenu', 'revenu_paul_essomba.txt', 'demo_revenu_paul_essomba.txt', 'en_attente'
FROM clients WHERE email = 'paul.essomba@example.cm';

INSERT INTO audit_log (utilisateur_id, action, cible_type, cible_id, details)
SELECT NULL, 'inscription_client', 'client', id, 'Auto-inscription de Paul Essomba depuis l''espace client'
FROM clients WHERE email = 'paul.essomba@example.cm';

-- Un client peut désormais être l'auteur d'une demande de crédit :
-- credits.demande_par référençait uniquement utilisateurs (staff).
-- On ajoute une colonne dédiée pour distinguer une auto-demande.
ALTER TABLE credits
    ADD COLUMN demande_par_client INT UNSIGNED NULL AFTER demande_par,
    ADD FOREIGN KEY (demande_par_client) REFERENCES clients(id) ON DELETE SET NULL;
