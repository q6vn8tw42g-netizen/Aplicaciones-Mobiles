-- Defensa en base de datos: ninguna reserva puede superar cinco minutos,
-- incluso si otra integración llama directamente al RPC existente.
create or replace function public.validar_duracion_reserva_cinco_minutos()
returns trigger
language plpgsql
as $$
begin
    if new.estado = 'RESERVADO' then
        if new.expiracion_reserva is null
           or new.expiracion_reserva > now() + interval '5 minutes' then
            raise exception 'La reserva no puede superar cinco minutos.'
                using errcode = 'P0001';
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists espacios_reservas_max_5_minutos on public.espacios;
create trigger espacios_reservas_max_5_minutos
    before insert or update of estado, expiracion_reserva on public.espacios
    for each row execute function public.validar_duracion_reserva_cinco_minutos();

-- Acorta cualquier reserva de diez minutos creada antes de esta regla.
update public.espacios
set expiracion_reserva = now() + interval '5 minutes'
where estado = 'RESERVADO'
  and expiracion_reserva > now() + interval '5 minutes';
