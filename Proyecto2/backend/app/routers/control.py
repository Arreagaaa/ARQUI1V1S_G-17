"""
Router de control — Endpoints de control de actuadores y modo de operación.

Endpoints requeridos por el enunciado:
  POST /api/control/irrigation — Control de riego (bomba)
  POST /api/control/lights     — Control de luces LED
  POST /api/control/fan        — Control de ventilación (extractor)
  POST /api/control/alarm      — Control de alarma (buzzer)
  POST /api/control/mode       — Cambio de modo de operación (auto/manual)

Endpoint legacy (mantenido por compatibilidad):
  POST /api/control/{actuator}
"""

import logging
from typing import Optional
from fastapi import APIRouter, Query, HTTPException

from ..schemas import ControlRequest, ModeChangeRequest
from ..services.control_service import execute_control

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Control"])


@router.post("/api/control/irrigation")
def control_irrigation(payload: ControlRequest):
    """
    Controla el sistema de riego (bomba).
    
    Valores válidos para state: 'on', 'off'
    """
    if payload.state not in ("on", "off"):
        raise HTTPException(status_code=400, detail="Estado inválido para riego. Usar 'on' o 'off'.")
    
    # Mapear internamente a "pump"
    return execute_control("pump", payload.state, payload.area)


@router.post("/api/control/lights")
def control_lights(payload: ControlRequest):
    """
    Controla el sistema de iluminación (luces LED).
    
    Valores válidos para state: 'on', 'off'
    """
    if payload.state not in ("on", "off"):
        raise HTTPException(status_code=400, detail="Estado inválido para luces. Usar 'on' o 'off'.")
        
    return execute_control("lights", payload.state, payload.area)


@router.post("/api/control/fan")
def control_fan(payload: ControlRequest):
    """
    Controla el extractor de aire (ventilador).
    
    Valores válidos para state: 'on', 'off'
    """
    if payload.state not in ("on", "off"):
        raise HTTPException(status_code=400, detail="Estado inválido para ventilador. Usar 'on' o 'off'.")
        
    return execute_control("fan", payload.state, payload.area)


@router.post("/api/control/alarm")
def control_alarm(payload: ControlRequest):
    """
    Controla la alarma sonora (buzzer).
    
    Valores válidos para state: 'on', 'off', 'mute'
    """
    if payload.state not in ("on", "off", "mute"):
        raise HTTPException(status_code=400, detail="Estado inválido para alarma. Usar 'on', 'off' o 'mute'.")
        
    # Mapear internamente a "buzzer"
    state_mapped = "off" if payload.state == "mute" else payload.state
    return execute_control("buzzer", state_mapped, payload.area)


@router.post("/api/control/mode")
def control_mode(payload: ModeChangeRequest):
    """
    Cambia el modo de operación del sistema.
    
    Valores válidos para mode: 'auto', 'manual'
    """
    return execute_control("mode", payload.mode, None)


# Mantener endpoint legacy para compatibilidad con frontend anterior
@router.post("/api/control/{actuator}")
def legacy_control_actuator(
    actuator: str, 
    state: str, 
    area: Optional[str] = Query(default=None)
):
    """
    Endpoint genérico legacy de control.
    Mapea a las llamadas de servicio correspondientes.
    """
    valid_actuators = ("pump", "fan", "lights", "buzzer", "mode")
    if actuator not in valid_actuators:
        raise HTTPException(status_code=400, detail=f"Actuador inválido '{actuator}'. Válidos: {valid_actuators}")
    
    return execute_control(actuator, state, area)
