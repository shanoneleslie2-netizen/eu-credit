const express = require('express');
const pool = require('../db');
const { authentifier, autoriserRoles } = require('../middleware/auth');

const router = express.Router();
router.use(authentifier);

// GET /api/audit — journal des actions, réservé admin + responsable (contrôle/traçabilité)
router.get('/', autoriserRoles('administrateur', 'responsable_credit'), async (req, res) => {
    try {
        const [rows] = await pool.query(
            `SELECT a.*, u.nom, u.prenom, u.role
             FROM audit_log a
             LEFT JOIN utilisateurs u ON a.utilisateur_id = u.id
             ORDER BY a.date_action DESC
             LIMIT 200`
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ erreur: 'Erreur lors de la récupération du journal.' });
    }
});

module.exports = router;
