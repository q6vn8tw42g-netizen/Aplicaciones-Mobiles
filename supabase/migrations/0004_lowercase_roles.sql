-- Canonicaliza los roles para que la base acepte únicamente minúsculas.
-- La API también compara sin distinguir mayúsculas para tolerar datos antiguos.
do $$
declare
    c record;
begin
    for c in
        select conname
        from pg_constraint
        where conrelid = 'public.perfiles'::regclass
          and contype = 'c'
          and pg_get_constraintdef(oid) ilike '%rol%'
    loop
        execute format('alter table public.perfiles drop constraint %I', c.conname);
    end loop;
end;
$$;

update public.perfiles set rol = lower(btrim(rol));
alter table public.perfiles alter column rol set default 'conductor';
alter table public.perfiles
    add constraint perfiles_rol_check
    check (rol in ('conductor', 'validador', 'admin'));

create or replace function public.manejar_nuevo_usuario()
returns trigger language plpgsql security definer set search_path=public as $$
begin
    insert into public.perfiles (id, nombre, rol)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'nombre', new.email, 'Usuario'),
        'conductor'
    );
    return new;
end;
$$;

drop policy if exists historial_select_autenticados on public.historial_estados;
create policy historial_select_autenticados on public.historial_estados
    for select to authenticated using (
        exists (
            select 1 from public.perfiles p
            where p.id = auth.uid() and lower(p.rol) in ('validador', 'admin')
        )
    );
