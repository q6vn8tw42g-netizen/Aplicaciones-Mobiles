from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class ForzarEstadoIn(BaseModel):
    estado: str = Field(..., pattern="^(LIBRE|OCUPADO|SIN_SERVICIO)$")
    minutos_bloqueo: int = Field(default=30, ge=1, le=240)


class ReporteConductorIn(BaseModel):
    espacio_id: UUID
    tipo: str = Field(..., pattern="^(ME_ESTACIONE|VOY_A_SALIR)$")
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)


class PerfilOut(BaseModel):
    id: str
    nombre: str
    rol: str
    puntos_karma: int
    creado_en: Optional[str] = None


class RoiRectIn(BaseModel):
    x: int = Field(..., ge=0)
    y: int = Field(..., ge=0)
    width: int = Field(..., gt=0)
    height: int = Field(..., gt=0)
    frame_width: int = Field(..., gt=0, le=16384)
    frame_height: int = Field(..., gt=0, le=16384)

    @model_validator(mode="after")
    def validate_bounds(self):
        if self.x + self.width > self.frame_width or self.y + self.height > self.frame_height:
            raise ValueError("El ROI debe quedar dentro de las dimensiones del frame.")
        return self


class CalibrarEspacioIn(RoiRectIn):
    espacio_id: UUID
    nombre: str = Field(..., min_length=1, max_length=120)
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)


class ReservarEspacioIn(BaseModel):
    tipo_vehiculo: Optional[str] = Field(
        default=None,
        pattern="^(MOTO|AUTO|CAMIONETA)$",
    )


class TipoVehiculoEspacioIn(BaseModel):
    tipo_vehiculo: str = Field(..., pattern="^(MOTO|AUTO|CAMIONETA|MIXTO)$")
