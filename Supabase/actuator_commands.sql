-- CoffeeMo bidirectional control table.
-- Run this once in Supabase SQL Editor before testing app -> hardware commands.

create table if not exists public.actuator_commands (
    command_id bigserial primary key,
    actuator_id text not null references public.actuators(actuator_id) on update cascade on delete restrict,
    command text not null check (command in ('on', 'off', 'auto', 'deployed', 'retracted')),
    requested_by text not null default 'ios_app',
    status text not null default 'pending' check (status in ('pending', 'processed', 'failed')),
    requested_at timestamptz not null default now(),
    processed_at timestamptz
);

create index if not exists idx_actuator_commands_pending
    on public.actuator_commands (status, requested_at);

create index if not exists idx_actuator_commands_actuator
    on public.actuator_commands (actuator_id, requested_at desc);

create or replace function public.set_actuator_command_processed_at()
returns trigger
language plpgsql
as $$
begin
    if new.status in ('processed', 'failed')
       and old.status is distinct from new.status
       and new.processed_at is null then
        new.processed_at := now();
    end if;
    return new;
end;
$$;

drop trigger if exists trg_set_actuator_command_processed_at on public.actuator_commands;
create trigger trg_set_actuator_command_processed_at
before update on public.actuator_commands
for each row
execute function public.set_actuator_command_processed_at();

alter table public.actuator_commands enable row level security;

drop policy if exists "anon can insert actuator commands" on public.actuator_commands;
create policy "anon can insert actuator commands"
on public.actuator_commands
for insert
to anon
with check (true);

drop policy if exists "anon can read actuator commands" on public.actuator_commands;
create policy "anon can read actuator commands"
on public.actuator_commands
for select
to anon
using (true);

drop policy if exists "anon can update actuator command status" on public.actuator_commands;
create policy "anon can update actuator command status"
on public.actuator_commands
for update
to anon
using (true)
with check (true);
