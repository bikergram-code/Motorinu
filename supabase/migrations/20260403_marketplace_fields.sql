-- Add shipping_type and is_negotiable fields to marketplace_listings
ALTER TABLE marketplace_listings
  ADD COLUMN IF NOT EXISTS shipping_type text DEFAULT 'pickup',
  ADD COLUMN IF NOT EXISTS is_negotiable boolean DEFAULT false;

-- Add comment for documentation
COMMENT ON COLUMN marketplace_listings.shipping_type IS 'pickup, shipping, or both';
COMMENT ON COLUMN marketplace_listings.is_negotiable IS 'VB (Verhandlungsbasis) flag';
