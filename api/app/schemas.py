from typing import Optional

from pydantic import BaseModel, Field


class ForzarEstadoIn(BaseModel):
    estado: str = Field(..., pattern="^(LIBRE|OCUPADO)$")
    minutos_bloqueo: int = Field(default=30, ge=1, le=240)


class ReporteConductorIn(BaseModel):
    espacio_id: int
    tipo: str = Field(..., pattern="^(ME_ESTACIONE|VOY_A_SALIR)$")
    latitud: float
    longitud: float


class PerfilOut(BaseModel):
    id: str
    nombre: str
    rol: str
    puntos_karma: int
    creado_en: Optional[str] = None
