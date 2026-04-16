-- Add review_text column to poi_ratings for written reviews
ALTER TABLE poi_ratings ADD COLUMN IF NOT EXISTS review_text text;
