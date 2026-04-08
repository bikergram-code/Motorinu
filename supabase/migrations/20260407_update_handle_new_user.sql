CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
begin
  insert into public.profiles (
    id,
    email,
    username,
    display_name,
    birth_year,
    postal_code,
    moto_start_age,
    car_start_age,
    has_track_experience,
    interested_in_dating,
    community,
    home_lat,
    home_lng
  )
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    (new.raw_user_meta_data->>'birth_year')::int,
    new.raw_user_meta_data->>'postal_code',
    (new.raw_user_meta_data->>'moto_start_age')::int,
    (new.raw_user_meta_data->>'car_start_age')::int,
    (new.raw_user_meta_data->>'has_track_experience')::boolean,
    (new.raw_user_meta_data->>'interested_in_dating')::boolean,
    new.raw_user_meta_data->>'community',
    (new.raw_user_meta_data->>'home_lat')::double precision,
    (new.raw_user_meta_data->>'home_lng')::double precision
  );
  return new;
end;
$$;
