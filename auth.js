const jwt = require('jsonwebtoken');

/** Vérifie la présence et la validité du jeton JWT (en-tête Authorization: Bearer ...) */
function authentifier(req, res, next) {
    const entete = req.headers['authorization'] || '';
    const jeton = entete.startsWith('Bearer ') ? entete.slice(7) : null;

    if (!jeton) {
        return res.status(401).json({ erreur: 'Authentification requise.' });
    }

    try {
        const payload = jwt.verify(jeton, process.env.JWT_SECRET);
        req.utilisateur = payload; // { id, email, role, nom, prenom, type: 'staff'|'client' }
        next();
    } catch (err) {
        return res.status(401).json({ erreur: 'Jeton invalide ou expiré.' });
    }
}

/** Restreint l'accès à une liste de rôles autorisés (comptes internes uniquement) */
function autoriserRoles(...rolesAutorises) {
    return (req, res, next) => {
        if (!req.utilisateur || req.utilisateur.type !== 'staff' || !rolesAutorises.includes(req.utilisateur.role)) {
            return res.status(403).json({ erreur: 'Accès refusé : rôle insuffisant.' });
        }
        next();
    };
}

/** Restreint l'accès aux seuls comptes clients (espace client) */
function autoriserClient(req, res, next) {
    if (!req.utilisateur || req.utilisateur.type !== 'client') {
        return res.status(403).json({ erreur: 'Accès réservé à l\'espace client.' });
    }
    next();
}

module.exports = { authentifier, autoriserRoles, autoriserClient };
