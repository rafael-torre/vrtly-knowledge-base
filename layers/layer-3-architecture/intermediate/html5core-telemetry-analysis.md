---
title: "Telemetry Analysis — html5core: Kill Zones and Instrumentation Gaps"
owner: "Tech Lead"
status: in_progress
last_updated: 2026-06-12
relates_to:
  - layers/layer-3-architecture/intermediate/investigation/telemetry-investigation-html5core.md
  - layers/layer-3-architecture/intermediate/playlist-update-flow-html5core.md
  - layers/layer-3-architecture/intermediate/blank-screen-scenarios.md
  - layers/layer-3-architecture/intermediate/tech-spike-html5core-player.md
  - layers/layer-3-architecture/intermediate/tech-spike-fmcom-player-api.md
  - layers/layer-3-architecture/intermediate/tech-spike-rnf.md
  - layers/layer-3-architecture/intermediate/tech-spike-state-service.md
  - layers/layer-3-architecture/intermediate/tech-spike-fmcom-api.md
---

# Telemetry Analysis — html5core: Kill Zones and Instrumentation Gaps

**Scope:** html5core fleet. Nodes N0–N8 from `playlist-update-flow-html5core.md`. Roku and Android out of scope.

**Method:** Two dimensions per node:
- **Dimension 1 — Kill zones:** code attempts to emit a signal but the signal does not survive to an observable layer.
- **Dimension 2 — Instrumentation gaps:** a blank-screen path exists where no code attempts to emit any signal.

Evidence grades: **Confirmed** = cited from tech spike or source analysis. **Deduced** = follows logically from confirmed evidence.

---

## Kill Zones — Dimension 1

Signals attempted but not surviving to any observability system.

| ID | Nodo | Señal intentada hoy | ¿Sobrevive? | Razón | ¿Reparable? | Señal alternativa |
|---|---|---|---|---|---|---|
| KZ-1 | N6 html5core | `sendIssue()` — cualquier error reportado por el player | **No** | `src/store/serverLogger.ts:38` tiene un `return` incondicional; dead code confirmado en spike | **Sí — mayor palanca** | Eliminar el early return; conectar con endpoint activo |
| KZ-2 | N6, N8 | Telemetría en localStorage cuando WebSocket offline extendido | **Parcial** | Buffer sin límite de tamaño ni TTL; browser storage eviction puede borrar eventos antes del flush | Sí | Cap de buffer FIFO; flush prioritario en reconexión de WS |
| KZ-3 | N1 fmcom-api | JMS dispatch post-commit (RNF_GENERATE / PLAYER_SCREEN_CONTENT_PENDING) | **No** (en crash post-commit) | `TransactionSynchronizationManager` defers dispatch; crash entre DB commit y send = mensaje perdido sin métrica del gap | Sí | Outbox pattern en MySQL; relay periódico |
| KZ-4 | N4 Message bus | PLAYER_* en State Service broker (in-memory) | **No** (en OOM-kill) | Broker in-process; snapshot a ES solo en shutdown limpio; OOM-kill no persiste mensajes en tránsito | Sí | Amazon MQ persistente para PLAYER_*; o snapshot frecuente |
| KZ-5 | N4 Message bus | PLAYER_* con client eviction por inactividad (5 min) | **No** | Offset del consumer reseteado silenciosamente al tail; mensajes durante la ventana se pierden sin log ni métrica | Sí | Aumentar ventana de eviction; offset persistente en Redis |
| KZ-6 | N5 fmcom-player-api | CONTENT_CHANGED para device offline >30s o cross-node ECS | **No** | UnsentNotice: in-memory, TTL 30s, cleanup c/10s; device que reconecta tarde o a nodo distinto no recibe el mensaje | Sí | Persistir UnsentNotice en Redis; TTL configurable >30s |
| KZ-7 | N3 RNF gen | PLAYER_*_UPDATED al ocurrir timeout de generación | **No** | `waitForCompletion` retorna vacío en silencio; solo un log line via `detectLongRunningTask`; sin métrica, sin alerta | Sí | Custom metric en CloudWatch + alerta en timeout rate |
| KZ-8 | N2 RNF transcode | PLAYER_CONTENT_TRANSCODED al fallar el pipeline | **No** (nunca se intenta) | El evento no se publica en el failure path de `UnifiedVideoPipeline`; falla = silencio desde N2 en adelante | Sí | Publicar TRANSCODE_FAILED a dead-letter queue; alerta en FAILED rate |
| KZ-9 | N3 RNF gen | PLAYER_*_UPDATED cuando ES write falla (phantom reload) | **Parcial — phantom** | Notificación llega al device, device blanquea y refetch, pero `ElasticPlaylistSchedule` no fue actualizado; content idéntico | Sí | Gatear publicación PLAYER_*_UPDATED en éxito de ES write |
| KZ-10 | N2 RNF transcode | Log + ECS exit en System.exit(-1) por State Service ping | **Parcial** | Llega como línea de log + task exit; sin métrica que distinga "State Service ping failure" de otro crash; IDs en pipeline al momento de exit no registrados | Sí | CloudWatch Alarm en patrón de log específico; registro de IDs en vuelo en Redis |

---

## Instrumentation Gaps — Dimension 2

Paths que llevan a blank screen sin que ningún código intente emitir señal alguna.

| ID | Nodo | Path que lleva a blank screen | ¿Existe alguna señal? | ¿Reparable? | Señal propuesta |
|---|---|---|---|---|---|
| IG-1 | N6 html5core | CONTENT_CHANGED recibido con `isConsults === true` → guard retorna, mensaje descartado | **Ninguna** (ni cliente ni servidor) | Sí | Evento de telemetría: `content_changed_dropped_consults` con timestamp |
| IG-2 | N6 html5core | Segundo CONTENT_CHANGED descartado por `__currentPlaylistLoading === true` | Ninguna | Sí | Evento de telemetría: `content_changed_dropped_concurrent` |
| IG-3 | N6, N7 | `setPlaylist([])` → PlaybackState.None — screen en blanco desde aquí hasta que llega la respuesta del fetch | Ninguna (solo ausencia de eventos de playback) | Sí | Eventos: `playlist_cleared` y `playlist_loaded` con timestamps |
| IG-4 | N6 html5core | CONTENT_CHANGED recibido y procesado — sin evento de receipt en el cliente | Ninguna | Sí | Evento de telemetría: `content_changed_received` con timestamp |
| IG-5 | N1 fmcom-api | Tier FREE/LOCKED: JMS suprimido intencionalmente sin log de la supresión | Ninguna | Sí | Log INFO al suprimir: `orgId`, `tier`, `reason = tier_suppressed` |
| IG-6 | N6a, N6b, N6c | Fetch falla → `apiRequest()` retorna `{}` → screen ya en blanco → sin señal hasta watchdog 20s después | Ninguna en el momento de la falla | Sí | Evento de telemetría: `playlist_fetch_failed` con HTTP status; no esperar al watchdog |
| IG-7 | N6d _parsePlaylist | Unknown contentType → `console.warn` → item descartado → si todos unknown, setPlaylist([]) efectivo | Ninguna (console.warn no llega al server) | Sí | Evento de telemetría: `unknown_content_type` por item descartado |
| IG-8 | N6c Combined playlist | Dynamic slot filtrado por `playlist.filter(c => c?.content?.contentType)` → contenido reducido o vacío | Ninguna | Sí | Log/evento cuando filter() elimina items del payload |
| IG-9 | N3 RNF gen | Screen saltada por timeout de generación → sin per-screen tracking de cuándo fue generada por última vez | Solo log general (no per-screen) | Sí | Campo `last_generated_at` en ElasticPlaylistSchedule; alerta en staleness >26h |
| IG-10 | N8 Watchdog | WATCHDOG events emitidos solo con `contentId` — sin campo de causa; `RESET_PLAYLIST` es idéntico para video congelado, playlist vacía o fetch fallido | WATCHDOG event (sin contexto causal) | Sí | Agregar campo `cause: EMPTY_PLAYLIST\|FETCH_FAILED\|FROZEN_CONTENT\|UNKNOWN` y `consecutive_count: N` al payload del WATCHDOG |
| IG-11 | N8 Watchdog | Múltiples `RESET_PLAYLIST` consecutivos del mismo device son indistinguibles de un reset aislado saludable — no hay detección de reload loop | WATCHDOG events (sin distinción de loop) | Sí | Campo `consecutive_resets: N` en payload de WATCHDOG + alarma server-side: device X emite >5 RESET_PLAYLIST en 5 minutos |

---

## Blank Screen Paths Sin Ninguna Señal

Los siguientes son los paths más críticos: el device llega a pantalla en blanco y no existe señal observable en ningún punto del stack.

### 1. CONTENT_CHANGED en consultation mode — zero signal en todo el stack [IG-1]

El WebSocket entrega el mensaje al device. `reloadCurrentPlaylist()` ejecuta el guard `isConsults === true` y retorna inmediatamente. El device no loguea nada. El server no sabe que el mensaje fue descartado. Después de la consulta, el device juega playlist desactualizado indefinidamente hasta que llegue otro CONTENT_CHANGED o el watchdog dispare por otra razón.

**Por qué importa:** Consultation mode puede estar activo durante ventanas de 15–30 minutos (duración de una consulta médica). Cualquier content update publicado durante esa ventana es silenciosamente perdida sin dejar rastro en ningún sistema. No hay forma de saber cuántos devices están en este estado en un momento dado.

---

### 2. setPlaylist([]) → PlaybackState.None — el blank window de cada reload normal [IG-3]

Cada llamada a `reloadCurrentPlaylist()` — exitosa o fallida — blanquea la pantalla antes de hacer el fetch. El período entre `setPlaylist([])` y `setPlaylist(newPlaylist)` no tiene ningún evento de telemetría. Aparece como la ausencia de eventos de playback, no como una señal positiva de "pantalla en blanco."

**Por qué importa:** Con org-wide fanout (S-19), todos los devices de una org blanquean simultáneamente en cada admin update. La duración agregada del blank screen a nivel de flota en cada update es completamente invisible. Este gap afecta **cada reload exitoso**, no solo los fallidos.

---

### 3. Fetch failure observable solo 20 segundos después [IG-6]

`apiRequest()` retorna `{}` sin excepción. La pantalla ya está en blanco (setPlaylist([]) se llamó primero). No hay evento al momento de la falla. La única señal observable es el PlaybackWatchdog que dispara 20 segundos después — un síntoma tardío, no la causa.

**Por qué importa:** El delay de 20s entre falla y primera señal hace imposible distinguir "device en un reload normal con red lenta" de "device al inicio de un reload loop" (S-3). No hay forma de intervenir proactivamente durante esos 20 segundos.

---

### 4. Unknown contentType en _parsePlaylist [IG-7]

Un `console.warn` en el cliente no llega al servidor. Si todos los items tienen contentType desconocido (player version lag vs. nuevo content type en backend), `setPlaylist([])` es el resultado efectivo. Screen en blanco con zero signal.

**Por qué importa:** Este path se activa silenciosamente después de un rollout de nuevo content type en el backend sin coordinación con el player. Un rollout incompleto puede blanquear un subconjunto de la flota con ningún sistema de alerta disponible para detectarlo.

---

### 5. Concurrent reload drop [IG-2]

Si org-wide fanout envía múltiples CONTENT_CHANGED en rápida sucesión, solo el primero es procesado. Los siguientes son descartados silenciosamente durante el reload en progreso. Si el primer reload falla y el watchdog luego dispara, el device no tiene forma de saber que habían señales adicionales pendientes.

---

## Resumen de Reparabilidad

| Categoría | Total findings | Reparables | Requieren cambios en html5core | Requieren cambios solo en backend |
|---|---|---|---|---|
| Kill zones (Dim 1) | 10 | 10 | 2 (KZ-1, KZ-2) | 8 |
| Instrumentation gaps (Dim 2) | 11 | 11 | 9 | 2 |

**Observación estructural:** La mayoría de los gaps no son reparables solo desde el backend. Nueve de los once gaps de Dimensión 2 requieren cambios en el player (html5core). La mayor palanca individual es KZ-1: restaurar `sendIssue()` en `serverLogger.ts` desbloquea el canal de error reporting diseñado y hace instrumentables IG-1, IG-6, IG-7 e IG-8 sin necesidad de nuevos endpoints de backend.

---

## Cobertura por Escenario

Para cada escenario de blank screen: si el momento del blank fue logueado, si el recovery fue logueado, y si se preservó contexto causal.

| Escenario | ¿Blank moment logueado? | ¿Recovery logueado? | ¿Contexto causal preservado? |
|---|---|---|---|
| Clear-before-fetch gap (cada reload normal) | No — PlaybackState.None filtrado [IG-3] | WATCHDOG a los 20s | No |
| Fetch failure → empty playlist | No [IG-6] | WATCHDOG a los 20s | No — causa no logueada |
| Bug encodeURIComponent (S-21) | No [IG-6] | WATCHDOG a los 20s | No — URL corrupta no logueada |
| Consultation mode descarta CONTENT_CHANGED | No [IG-1] | No | No |
| serverLogger dead | — | — | Todo el error reporting server-side deshabilitado [KZ-1] |
| Session miss multi-node | CONNECTION_STATE en reconexión | Parcial | No — push perdido no logueado [KZ-6] |
| UnsentNotice TTL expiry | CONNECTION_STATE en reconexión | Parcial | No — notice expirado no logueado [KZ-6] |
| Org-wide fanout (todos los devices blanquean) | No — mismo gap que clear-before-fetch [IG-3] | WATCHDOG si persiste | No |
| FREE/LOCKED tier — content desactualizado hasta 24h | No | No | Sin señal en ningún punto del stack [IG-5] |
| RNF generation timeout | Log `detectLongRunningTask` (solo CloudWatch) | No | No — log sin alarma [KZ-7] |
| State Service OOM-kill pierde mensajes | CloudWatch task stop event | No | Sin correlación con CONTENT_CHANGED perdido [KZ-4] |
| Concurrent-reload guard descarta CONTENT_CHANGED | No [IG-2] | No | No |
| Watchdog reload loop (loop destructivo) | WATCHDOG events (sin distinción de loop) [IG-11] | WATCHDOG a los 30s (RESET_APP) | No — loop saludable y roto son idénticos |

---

## Hallazgos Transversales

Estos patrones aplican a múltiples nodos y representan brechas sistémicas:

1. **El PlaybackWatchdog es recovery, no diagnóstico.** Todos los blank-screen paths desembocan en el mismo evento de watchdog. No hay forma de distinguir la causa desde el evento. El watchdog fue diseñado para recuperar el device, no para diagnosticar el origen del blank screen.

2. **State Service es single point of failure para el routing de telemetría.** Un OOM-kill de State Service destruye simultáneamente: los mensajes PLAYER_* en el broker (KZ-4), el throughput de generación de playlists vía ES quota (amplifica KZ-7), y el contexto de IDs en transcoding (KZ-10). La falla destruye múltiples señales que habrían documentado la falla misma.

3. **Org-wide fanout multiplica el blast radius de cada kill zone.** S-19: cada admin action genera CONTENT_CHANGED para todos los devices del org. Cada KZ que mata un CONTENT_CHANGED afecta potencialmente a toda la flota del org, no a un device. Cada IG-3 (blank window de reload) ocurre simultáneamente en toda la org.

4. **`serverLogger.ts` dead code es el techo estructural de la observabilidad del player.** Sin este canal funcional, el player solo puede comunicar anomalías a través del canal de telemetría batched (WebSocket → localStorage → flush), que a su vez tiene su propio riesgo de pérdida (KZ-2). No hay canal de error reporting separado y de alta prioridad.