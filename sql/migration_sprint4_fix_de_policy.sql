-- Sprint 4: Fix DE country policy — change from 'off' to 'exact' (allowed)
-- Blitzer apps are widely used in Germany (Blitzer.de, Waze etc.)
-- Only usage while actively driving is debatable, not the display itself.

UPDATE blitzer_country_policy
SET mode = 'exact',
    allow_reporting = true,
    allow_audio_alerts = true,
    notes = 'Germany - allowed (user responsibility while driving)',
    updated_at = now()
WHERE country_code = 'DE';
