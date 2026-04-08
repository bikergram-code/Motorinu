-- Vehicle Likes
CREATE TABLE IF NOT EXISTS vehicle_likes (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  vehicle_id bigint NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(vehicle_id, user_id)
);

ALTER TABLE vehicle_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all vehicle likes"
  ON vehicle_likes FOR SELECT USING (true);

CREATE POLICY "Users can like/unlike vehicles"
  ON vehicle_likes FOR ALL USING (auth.uid() = user_id);

-- Vehicle Offers (Kleinanzeigen-style negotiation)
CREATE TABLE IF NOT EXISTS vehicle_offers (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  vehicle_id bigint NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount decimal(12,2) NOT NULL,
  message text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'countered')),
  parent_offer_id bigint REFERENCES vehicle_offers(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE vehicle_offers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can see their own offers (sent or received)"
  ON vehicle_offers FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = owner_id);

CREATE POLICY "Users can create offers"
  ON vehicle_offers FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Participants can update offers"
  ON vehicle_offers FOR UPDATE
  USING (auth.uid() = sender_id OR auth.uid() = owner_id);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_vehicle_likes_vehicle ON vehicle_likes(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_offers_vehicle ON vehicle_offers(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_offers_sender ON vehicle_offers(sender_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_offers_owner ON vehicle_offers(owner_id);
