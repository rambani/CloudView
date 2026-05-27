-- CloudView database schema
-- Run this in your Supabase SQL editor to initialize the database

-- Enable PostGIS for geo queries (optional, skip if not available)
-- create extension if not exists postgis;

-- ────────────────────────────────────────────────────────────
-- Profiles (extends Supabase auth.users)
-- ────────────────────────────────────────────────────────────
create table if not exists profiles (
    id          uuid primary key references auth.users on delete cascade,
    username    text unique not null,
    avatar_url  text,
    city        text,
    total_sightings int not null default 0,
    streak_days     int not null default 0,
    last_active_at  timestamp with time zone,
    created_at  timestamp with time zone default now()
);

alter table profiles enable row level security;

create policy "Public profiles are viewable by everyone"
    on profiles for select using (true);

create policy "Users can update their own profile"
    on profiles for update using (auth.uid() = id);

create policy "Users can insert their own profile"
    on profiles for insert with check (auth.uid() = id);

-- ────────────────────────────────────────────────────────────
-- Sightings
-- ────────────────────────────────────────────────────────────
create table if not exists sightings (
    id                  uuid primary key default gen_random_uuid(),
    user_id             uuid references profiles(id) on delete set null,
    image_url           text not null,
    shape_name          text not null,
    quip                text not null,
    cloud_type          text not null,
    weather_mood        text not null,
    watchability_score  int not null check (watchability_score between 1 and 10),
    drawing_paths       jsonb not null default '{}',
    latitude            double precision,
    longitude           double precision,
    city                text,
    country             text,
    likes               int not null default 0,
    created_at          timestamp with time zone default now()
);

create index if not exists sightings_created_at_idx on sightings (created_at desc);
create index if not exists sightings_user_id_idx on sightings (user_id);
create index if not exists sightings_city_idx on sightings (city);
create index if not exists sightings_location_idx on sightings (latitude, longitude)
    where latitude is not null and longitude is not null;

alter table sightings enable row level security;

create policy "Sightings are viewable by everyone"
    on sightings for select using (true);

create policy "Authenticated users can insert sightings"
    on sightings for insert with check (auth.uid() = user_id);

create policy "Users can update their own sightings"
    on sightings for update using (auth.uid() = user_id);

create policy "Users can delete their own sightings"
    on sightings for delete using (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- Likes
-- ────────────────────────────────────────────────────────────
create table if not exists sighting_likes (
    sighting_id uuid not null references sightings(id) on delete cascade,
    user_id     uuid not null references profiles(id) on delete cascade,
    created_at  timestamp with time zone default now(),
    primary key (sighting_id, user_id)
);

alter table sighting_likes enable row level security;

create policy "Likes are viewable by everyone"
    on sighting_likes for select using (true);

create policy "Authenticated users can like"
    on sighting_likes for insert with check (auth.uid() = user_id);

create policy "Users can unlike their own likes"
    on sighting_likes for delete using (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- Storage bucket
-- ────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('sighting-images', 'sighting-images', true)
on conflict (id) do nothing;

create policy "Anyone can view sighting images"
    on storage.objects for select
    using (bucket_id = 'sighting-images');

create policy "Authenticated users can upload to their folder"
    on storage.objects for insert
    with check (
        bucket_id = 'sighting-images'
        and auth.uid()::text = (storage.foldername(name))[1]
    );

create policy "Users can delete their own images"
    on storage.objects for delete
    using (
        bucket_id = 'sighting-images'
        and auth.uid()::text = (storage.foldername(name))[1]
    );

-- ────────────────────────────────────────────────────────────
-- Functions
-- ────────────────────────────────────────────────────────────

-- Toggle like and keep the likes counter denormalized on sightings
create or replace function toggle_like(p_sighting_id uuid, p_user_id uuid)
returns json
language plpgsql security definer as $$
declare
    v_liked boolean;
begin
    if exists (select 1 from sighting_likes where sighting_id = p_sighting_id and user_id = p_user_id) then
        delete from sighting_likes where sighting_id = p_sighting_id and user_id = p_user_id;
        update sightings set likes = greatest(0, likes - 1) where id = p_sighting_id;
        v_liked := false;
    else
        insert into sighting_likes (sighting_id, user_id) values (p_sighting_id, p_user_id);
        update sightings set likes = likes + 1 where id = p_sighting_id;
        v_liked := true;
    end if;
    return json_build_object('liked', v_liked);
end;
$$;

-- Increment sightings count
create or replace function increment_sightings(user_id_input text)
returns void
language plpgsql security definer as $$
begin
    update profiles
    set total_sightings = total_sightings + 1,
        last_active_at = now()
    where id = user_id_input::uuid;
end;
$$;

-- City statistics for the map
create or replace function city_sighting_stats()
returns table (
    city        text,
    country     text,
    count       bigint,
    latitude    double precision,
    longitude   double precision,
    recent_shapes text[]
)
language sql stable as $$
    select
        s.city,
        s.country,
        count(*) as count,
        avg(s.latitude) as latitude,
        avg(s.longitude) as longitude,
        array_agg(s.shape_name order by s.created_at desc) filter (where s.shape_name is not null) [1:5] as recent_shapes
    from sightings s
    where s.city is not null
      and s.latitude is not null
    group by s.city, s.country
    order by count desc
    limit 100;
$$;

-- Nearby sightings within radius_km kilometers
create or replace function sightings_within_radius(lat double precision, lon double precision, radius_km double precision)
returns setof sightings
language sql stable as $$
    select *
    from sightings
    where latitude is not null
      and longitude is not null
      and (
          6371 * acos(
              cos(radians(lat)) * cos(radians(latitude)) *
              cos(radians(longitude) - radians(lon)) +
              sin(radians(lat)) * sin(radians(latitude))
          )
      ) <= radius_km
    order by created_at desc
    limit 50;
$$;
