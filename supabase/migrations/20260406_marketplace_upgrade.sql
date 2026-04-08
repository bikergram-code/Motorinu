-- Marktplatz-Upgrade: Unterkategorien + Attribute (JSONB)
-- Ermöglicht mobile.de + eBay Kleinanzeigen Funktionalität

-- Neue Spalten
ALTER TABLE marketplace_listings ADD COLUMN IF NOT EXISTS subcategory text;
ALTER TABLE marketplace_listings ADD COLUMN IF NOT EXISTS attributes jsonb DEFAULT '{}';

-- Indices für Performance
CREATE INDEX IF NOT EXISTS idx_listings_subcategory ON marketplace_listings(subcategory);
CREATE INDEX IF NOT EXISTS idx_listings_attributes ON marketplace_listings USING gin(attributes);
CREATE INDEX IF NOT EXISTS idx_listings_category_subcategory ON marketplace_listings(category, subcategory);

-- Bestehende Kategorien umbenennen
UPDATE marketplace_listings SET category = 'Ersatzteile' WHERE category = 'Teile';
UPDATE marketplace_listings SET category = 'Motorrad-Bekleidung' WHERE category = 'Bekleidung';
