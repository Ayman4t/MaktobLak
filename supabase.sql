-- 1) Spec table (verbatim)
create table letters (
  id uuid primary key default gen_random_uuid(),
  recipient_name text not null,          -- اسم الشخص (مثل: نور، أحمد)
  shared_clue text not null,             -- البصمة السرية المشتركة
  place_tag text not null,               -- المكان أو الجامعة (مثل: الزمالك، جامعة عين شمس)
  category text not null,                -- حنين، عتاب، اعتراف، امتنان، وداع
  message text not null,                 -- نص الرسالة
  bg_color text default '#1e1b4b',      -- لون الكارت المختار
  likes_count integer default 0,
  created_at timestamp with time zone default now()
);
create index idx_letters_search on letters (recipient_name, place_tag, category);

-- 2) Optional: signature shown on the card ("من:"). The site works without it.
alter table letters add column sender_alias text;

-- 3) Safety: server-side limits (the anon key is public, so never rely on the browser alone)
alter table letters add constraint letters_limits check (
  char_length(recipient_name) <= 30 and char_length(shared_clue) <= 90 and char_length(place_tag) <= 40
  and char_length(message) <= 350 and coalesce(char_length(sender_alias), 0) <= 24
  and category in ('حنين','اعتراف','عتاب','امتنان','وداع')
  and bg_color ~ '^#[0-9a-fA-F]{6}$'
);

-- 4) Row Level Security: public read + insert only (no update/delete from the browser)
alter table letters enable row level security;
create policy "read letters"   on letters for select using (true);
create policy "insert letters" on letters for insert with check (likes_count = 0);

create or replace function increment_likes(row_id uuid, delta int)
returns void language sql security definer set search_path = public as $$
  update letters set likes_count = greatest(likes_count + delta, 0) where id = row_id;
$$;

create table reports (id bigint generated always as identity primary key, letter_id uuid, created_at timestamptz default now());
alter table reports enable row level security;
create policy "insert reports" on reports for insert with check (true);

-- 5) Live updates for new letters
alter publication supabase_realtime add table letters;
