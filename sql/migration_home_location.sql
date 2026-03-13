-- Add home_lat / home_lng to profiles table for GPS-based home position.
-- Replaces PLZ-geocoding which is unreliable for international postal codes.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS home_lat double precision;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS home_lng double precision;
