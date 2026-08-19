-- ============================================================
-- Express Union Finance — Système d'octroi de crédit
-- Schéma de base de données + données de démonstration
-- ============================================================

CREATE DATABASE IF NOT EXISTS eu_credit CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE eu_credit;

-- ============================================================
-- TABLE : utilisateurs
-- Comptes internes (administrateur, agent de crédit, responsable)
-- ============================================================
CREATE TABLE IF NOT EXISTS utilisateurs (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nom             VARCHAR(100)    NOT NULL,
    prenom          VARCHAR(100)    NOT NULL,
    email           VARCHAR(150)    NOT NULL UNIQUE,
    mot_de_passe    VARCHAR(255)    NOT NULL,           -- hash bcrypt, jamais en clair
    role            ENUM('administrateur','agent_credit','responsable_credit') NOT NULL,
    statut          ENUM('actif','inactif') NOT NULL DEFAULT 'actif',
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- ============================================================
-- TABLE : clients
-- ============================================================
CREATE TABLE IF NOT EXISTS clients (
    id                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nom                 VARCHAR(100)    NOT NULL,
    prenom              VARCHAR(100)    NOT NULL,
    email               VARCHAR(150)    NULL UNIQUE,        -- rempli si le client s'est auto-inscrit
    mot_de_passe        VARCHAR(255)    NULL,                -- hash bcrypt, requis pour l'auto-inscription
    telephone           VARCHAR(20)     NOT NULL,
    adresse             VARCHAR(255)    NULL,
    profession          VARCHAR(100)    NULL,
    revenu_mensuel      DECIMAL(12,2)   NOT NULL DEFAULT 0,
    statut_verification ENUM('en_attente','verifie','rejete') NOT NULL DEFAULT 'en_attente',
    cree_via            ENUM('agent','auto_inscription') NOT NULL DEFAULT 'agent',
    cree_par            INT UNSIGNED    NULL,               -- agent qui a enregistré le client (NULL si auto-inscription)
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (cree_par) REFERENCES utilisateurs(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
-- TABLE : credits
-- Une ligne = une demande de crédit, avec sa décision et sa justification
-- ============================================================
CREATE TABLE IF NOT EXISTS credits (
    id                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    client_id           INT UNSIGNED    NOT NULL,
    montant             DECIMAL(12,2)   NOT NULL,
    duree_mois          SMALLINT UNSIGNED NOT NULL,
    taux_pourcent       DECIMAL(5,2)    NOT NULL DEFAULT 10.00,  -- taux flat sur la durée du prêt
    mensualite          DECIMAL(12,2)   NOT NULL,               -- calculée automatiquement
    taux_endettement    DECIMAL(5,2)    NOT NULL,               -- mensualite / revenu, en %
    statut              ENUM('en_attente','approuve','rejete')  NOT NULL DEFAULT 'en_attente',
    decision_auto       ENUM('ACCEPTE','REJETE')                NOT NULL, -- résultat du moteur de règles
    motif_decision      VARCHAR(255)    NOT NULL,
    commentaire_responsable VARCHAR(255) NULL,          -- ajouté par le responsable à la validation manuelle
    demande_par         INT UNSIGNED    NULL,           -- agent qui a saisi la demande (NULL si le client l'a faite lui-même)
    demande_par_client  INT UNSIGNED    NULL,           -- client qui a saisi lui-même sa demande (espace client)
    valide_par          INT UNSIGNED    NULL,           -- responsable qui a validé/rejeté manuellement
    date_demande        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_decision       TIMESTAMP       NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (client_id)          REFERENCES clients(id)      ON DELETE CASCADE,
    FOREIGN KEY (demande_par)        REFERENCES utilisateurs(id) ON DELETE SET NULL,
    FOREIGN KEY (demande_par_client) REFERENCES clients(id)      ON DELETE SET NULL,
    FOREIGN KEY (valide_par)         REFERENCES utilisateurs(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
-- TABLE : remboursements
-- ============================================================
CREATE TABLE IF NOT EXISTS remboursements (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    credit_id       INT UNSIGNED    NOT NULL,
    montant         DECIMAL(12,2)   NOT NULL,
    date_paiement   DATE            NOT NULL,
    enregistre_par  INT UNSIGNED    NULL,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (credit_id)      REFERENCES credits(id)      ON DELETE CASCADE,
    FOREIGN KEY (enregistre_par) REFERENCES utilisateurs(id) ON DELETE SET NULL
) ENGINE=InnoDB;

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

-- ============================================================
-- TABLE : audit_log
-- Trace qui a fait quoi, quand — répond à l'exigence de traçabilité
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_log (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    utilisateur_id  INT UNSIGNED    NULL,
    action          VARCHAR(50)     NOT NULL,   -- ex: connexion, creation_credit, validation_credit...
    cible_type      VARCHAR(50)     NULL,       -- ex: client, credit, remboursement, utilisateur
    cible_id        INT UNSIGNED    NULL,
    details         VARCHAR(500)    NULL,
    date_action     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE INDEX idx_credits_statut     ON credits(statut);
CREATE INDEX idx_credits_client     ON credits(client_id);
CREATE INDEX idx_remb_credit        ON remboursements(credit_id);
CREATE INDEX idx_audit_date         ON audit_log(date_action);
CREATE INDEX idx_audit_utilisateur  ON audit_log(utilisateur_id);
CREATE INDEX idx_documents_client   ON documents_clients(client_id);
CREATE INDEX idx_documents_statut   ON documents_clients(statut);

-- ============================================================
-- DONNÉES DE DÉMONSTRATION
-- Comptes utilisateurs (mots de passe en clair rappelés dans le README,
-- ils sont ici hachés en bcrypt — jamais stockés en clair en base)
--   admin@euf.cm            / Admin@2026        (administrateur)
--   agent@euf.cm            / Agent@2026        (agent_credit)
--   responsable@euf.cm      / Responsable@2026  (responsable_credit)
-- ============================================================
INSERT INTO utilisateurs (nom, prenom, email, mot_de_passe, role) VALUES
('Ateba',  'Marie',   'admin@euf.cm',       '$2a$10$juSf6dguks6SPFlfhVEdyOwUki.ip06Rnbk8fGcrImCBeq6WORw4i', 'administrateur'),
('Ngola',  'Clementine', 'agent@euf.cm',    '$2a$10$cgFbzSurb7hF2NtZSnx7zOnBAMz0aZ/GYDgn2oGG6dr5GCCXSE.We', 'agent_credit'),
('Mboa',   'Jean',     'responsable@euf.cm','$2a$10$ISIZkZ2/4Syo2ezqqbDtpOfOnI6gBW7EbzIGsSybs.JAgumyr/6dm', 'responsable_credit');

-- Clients de démonstration
INSERT INTO clients (nom, prenom, telephone, adresse, profession, revenu_mensuel, cree_par) VALUES
('Ngola', 'Clementine', '677001122', 'Bastos, Yaoundé',  'Enseignante',      350000, 2),
('Mboa',  'Jean',       '699112233', 'Mvan, Yaoundé',    'Commerçant',       500000, 2),
('Fouda', 'Alain',      '655334455', 'Ngousso, Yaoundé', 'Chauffeur',        180000, 2),
('Biya',  'Sylvie',     '691223344', 'Essos, Yaoundé',   'Infirmière',       420000, 2);

-- Les clients saisis par un agent sont considérés vérifiés (l'agent a déjà
-- contrôlé leur identité en présentiel au moment de la saisie)
UPDATE clients SET statut_verification = 'verifie' WHERE cree_via = 'agent';

-- Un client de démonstration qui s'est auto-inscrit depuis l'espace client,
-- en attente de vérification de ses documents par un agent
-- (mot de passe de démo : Client@2026 — hash bcrypt ci-dessous)
INSERT INTO clients (nom, prenom, email, mot_de_passe, telephone, adresse, profession,
                      revenu_mensuel, statut_verification, cree_via) VALUES
('Essomba', 'Paul', 'paul.essomba@example.cm',
 '$2a$10$2ZXhMxioZo4Z8f/ShTwGM.Y.yoHp01/c4cvOUO.PkO.csWIfKIOM6',
 '694556677', 'Nkolbisson, Yaoundé', 'Menuisier', 275000, 'en_attente', 'auto_inscription');

-- Demandes de crédit de démonstration (les mensualités/taux d'endettement
-- sont recalculés par l'application ; ces valeurs illustrent des cas
-- représentatifs : un accepté, un rejeté, un en attente)
INSERT INTO credits (client_id, montant, duree_mois, taux_pourcent, mensualite, taux_endettement,
                      statut, decision_auto, motif_decision, demande_par, valide_par, date_decision) VALUES
(1, 100000, 2,  10.00, 55000.00, 15.71, 'approuve', 'ACCEPTE',
   'Taux d''endettement de 15.71% (<= 40%) : mensualité compatible avec le revenu déclaré.',
   2, 3, NOW()),
(3, 600000, 6,  10.00, 110000.00, 61.11, 'rejete', 'REJETE',
   'Taux d''endettement de 61.11% (> 40%) : mensualité incompatible avec le revenu déclaré.',
   2, 3, NOW()),
(2, 300000, 4,  10.00, 82500.00, 16.50, 'en_attente', 'ACCEPTE',
   'Taux d''endettement de 16.50% (<= 40%) : mensualité compatible avec le revenu déclaré.',
   2, NULL, NULL);

-- Remboursement de démonstration sur le crédit approuvé (id=1)
INSERT INTO remboursements (credit_id, montant, date_paiement, enregistre_par) VALUES
(1, 55000.00, CURDATE(), 2);

-- Documents de démonstration pour le client auto-inscrit (en attente de vérification)
INSERT INTO documents_clients (client_id, type_document, nom_original, chemin_fichier, statut) VALUES
(5, 'cni',                'cni_paul_essomba.txt',    'demo_cni_paul_essomba.txt',    'en_attente'),
(5, 'justificatif_revenu','revenu_paul_essomba.txt', 'demo_revenu_paul_essomba.txt', 'en_attente');

-- Journal d'audit de démonstration
INSERT INTO audit_log (utilisateur_id, action, cible_type, cible_id, details) VALUES
(2, 'connexion', 'utilisateur', 2, 'Connexion réussie'),
(2, 'creation_client', 'client', 1, 'Client Ngola Clementine enregistré'),
(2, 'creation_credit', 'credit', 1, 'Demande de 100000 FCFA sur 2 mois'),
(3, 'validation_credit', 'credit', 1, 'Crédit approuvé manuellement'),
(2, 'creation_credit', 'credit', 2, 'Demande de 600000 FCFA sur 6 mois'),
(3, 'rejet_credit', 'credit', 2, 'Crédit rejeté manuellement'),
(2, 'enregistrement_remboursement', 'remboursement', 1, 'Paiement de 55000 FCFA enregistré'),
(NULL, 'inscription_client', 'client', 5, 'Auto-inscription de Paul Essomba depuis l''espace client'),
(NULL, 'upload_document', 'document', 1, 'Pièce CNI déposée par Paul Essomba'),
(NULL, 'upload_document', 'document', 2, 'Justificatif de revenu déposé par Paul Essomba');
