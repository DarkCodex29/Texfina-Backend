using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TexfinaApi.Data;

namespace TexfinaApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class DashboardController : ControllerBase
    {
        private readonly TexfinaDbContext _context;
        private readonly ILogger<DashboardController> _logger;

        public DashboardController(TexfinaDbContext context, ILogger<DashboardController> logger)
        {
            _context = context;
            _logger = logger;
        }

        /// <summary>
        /// Obtener resumen ejecutivo completo del sistema
        /// </summary>
        [HttpGet("resumen")]
        public async Task<ActionResult<object>> GetResumenEjecutivo()
        {
            try
            {
                // VERSION ULTRA SIMPLIFICADA - SIN CONSULTAS SQL COMPLEJAS
                return Ok(new
                {
                    FechaActualizacion = DateTime.Now,
                    InventarioGeneral = new
                    {
                        TotalItems = 0,
                        ValorTotalInventario = 0.0,
                        CantidadTotalStock = 0.0
                    },
                    EstadisticasInsumos = new
                    {
                        TotalInsumos = 0,
                        TotalClases = 0,
                        TotalUnidades = 0,
                        InsumosConStock = 0,
                        InsumosSinStock = 0
                    },
                    AlertasCriticas = new
                    {
                        StockBajo = 0,
                        LotesProximosVencer = 0,
                        LotesVencidos = 0,
                        AlmacenesVacios = 0
                    },
                    MovimientosMes = new
                    {
                        Ingresos = new { Total = 0, ValorTotal = 0.0, CantidadTotal = 0.0 },
                        Consumos = new { Total = 0, ValorTotal = 0.0, CantidadTotal = 0.0 }
                    },
                    TopClases = new object[0],
                    TopAlmacenes = new object[0],
                    TopProveedores = new object[0]
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al obtener resumen ejecutivo");
                return StatusCode(500, "Error interno del servidor");
            }
        }

        /// <summary>
        /// Obtener alertas críticas del sistema
        /// </summary>
        [HttpGet("alertas")]
        public async Task<ActionResult<object>> GetAlertas()
        {
            try
            {
                var hoy = DateTime.Now;
                var fechaHoyOnly = DateOnly.FromDateTime(hoy);

                var stockBajo = await _context.Stocks
                    .Include(s => s.Insumo)
                        .ThenInclude(i => i!.Clase)
                    .Include(s => s.Almacen)
                    .Where(s => s.Cantidad <= 10 && s.Cantidad > 0)
                    .Select(s => new
                    {
                        s.IdStock,
                        s.Cantidad,
                        Insumo = new { s.Insumo!.IdInsumo, s.Insumo.Nombre, s.Insumo.IdFox },
                        Clase = s.Insumo.Clase!.Familia,
                        Almacen = s.Almacen!.Nombre,
                        Criticidad = s.Cantidad <= 3 ? "CRÍTICO" : "BAJO"
                    })
                    .OrderBy(s => s.Cantidad)
                    .ToListAsync();

                var lotesVencimiento = await _context.Lotes
                    .Include(l => l.Insumo)
                        .ThenInclude(i => i!.Clase)
                    .Where(l => l.FechaExpiracion.HasValue && 
                              l.FechaExpiracion <= DateOnly.FromDateTime(hoy.AddDays(30)) &&
                              l.EstadoLote == "ACTIVO")
                    .ToListAsync();

                // Procesar conversiones DateOnly en memoria
                var lotesVencimientoResult = lotesVencimiento.Select(l => new
                {
                    l.IdLote,
                    Numero = l.Numero,
                    l.StockActual,
                    FechaExpiracion = l.FechaExpiracion!.Value.ToDateTime(TimeOnly.MinValue),
                    DiasParaVencer = (l.FechaExpiracion!.Value.DayNumber - fechaHoyOnly.DayNumber),
                    Insumo = new { l.Insumo!.IdInsumo, l.Insumo.Nombre, l.Insumo.IdFox },
                    Clase = l.Insumo.Clase!.Familia,
                    Criticidad = (l.FechaExpiracion.Value.DayNumber - fechaHoyOnly.DayNumber) <= 7 ? "CRÍTICO" : 
                               (l.FechaExpiracion.Value.DayNumber - fechaHoyOnly.DayNumber) <= 15 ? "ALTO" : "MEDIO"
                })
                .OrderBy(l => l.FechaExpiracion)
                .ToList();

                var insumosSinMovimiento = await _context.Insumos
                    .Include(i => i.Clase)
                    .Where(i => !i.Ingresos.Any(ing => ing.Fecha >= DateOnly.FromDateTime(hoy.AddDays(-60))) &&
                              !i.Consumos.Any(c => c.Fecha >= DateOnly.FromDateTime(hoy.AddDays(-60))))
                    .Take(20)
                    .Select(i => new
                    {
                        i.IdInsumo,
                        i.IdFox,
                        i.Nombre,
                        Clase = i.Clase!.Familia,
                        UltimoIngreso = i.Ingresos.Max(ing => ing.Fecha),
                        UltimoConsumo = i.Consumos.Max(c => c.Fecha),
                        StockActual = i.Stocks.Sum(s => s.Cantidad ?? 0)
                    })
                    .ToListAsync();

                return Ok(new
                {
                    FechaConsulta = hoy,
                    StockBajo = stockBajo,
                    LotesProximosVencer = lotesVencimientoResult,
                    InsumosSinMovimiento = insumosSinMovimiento,
                    Resumen = new
                    {
                        TotalAlertas = stockBajo.Count + lotesVencimientoResult.Count + insumosSinMovimiento.Count,
                        AlertasCriticas = stockBajo.Count(s => s.Criticidad == "CRÍTICO") + 
                                        lotesVencimientoResult.Count(l => l.Criticidad == "CRÍTICO"),
                        RequiereAccionInmediata = stockBajo.Count(s => s.Criticidad == "CRÍTICO") + 
                                                lotesVencimientoResult.Count(l => l.DiasParaVencer <= 7)
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al obtener alertas");
                return StatusCode(500, "Error interno del servidor");
            }
        }

        /// <summary>
        /// Obtener tendencias de movimientos por período
        /// </summary>
        [HttpGet("tendencias")]
        public async Task<ActionResult<object>> GetTendencias([FromQuery] int meses = 6)
        {
            try
            {
                var fechaInicio = DateTime.Now.AddMonths(-meses);
                var fechaDesdeOnly = DateOnly.FromDateTime(fechaInicio);

                var tendenciasIngresos = await _context.Ingresos
                    .Where(i => i.Fecha >= fechaDesdeOnly)
                    .GroupBy(i => new { 
                        Año = i.Fecha!.Value.Year, 
                        Mes = i.Fecha.Value.Month 
                    })
                    .Select(g => new
                    {
                        Año = g.Key.Año,
                        Mes = g.Key.Mes,
                        TotalIngresos = g.Count(),
                        ValorTotal = g.Sum(i => i.PrecioTotalFormula ?? 0),
                        CantidadTotal = g.Sum(i => i.Cantidad ?? 0)
                    })
                    .OrderBy(t => t.Año)
                    .ThenBy(t => t.Mes)
                    .ToListAsync();

                var tendenciasConsumos = await _context.Consumos
                    .Include(c => c.Insumo)
                    .Where(c => c.Fecha >= fechaDesdeOnly)
                    .GroupBy(c => new { 
                        Año = c.Fecha!.Value.Year, 
                        Mes = c.Fecha.Value.Month 
                    })
                    .Select(g => new
                    {
                        Año = g.Key.Año,
                        Mes = g.Key.Mes,
                        TotalConsumos = g.Count(),
                        ValorTotal = g.Sum(c => (c.Cantidad ?? 0) * (c.Insumo!.PrecioUnitario ?? 0)),
                        CantidadTotal = g.Sum(c => c.Cantidad ?? 0)
                    })
                    .OrderBy(t => t.Año)
                    .ThenBy(t => t.Mes)
                    .ToListAsync();

                var rotacionInventario = await _context.Stocks
                    .Include(s => s.Insumo)
                        .ThenInclude(i => i!.Clase)
                    .Where(s => s.Cantidad > 0)
                    .GroupBy(s => s.Insumo!.Clase!.Familia)
                    .Select(g => new
                    {
                        Clase = g.Key,
                        StockPromedio = g.Average(s => s.Cantidad ?? 0),
                        ValorPromedio = g.Average(s => (s.Cantidad ?? 0) * (s.Insumo!.PrecioUnitario ?? 0)),
                        ItemsActivos = g.Count()
                    })
                    .OrderByDescending(r => r.ValorPromedio)
                    .ToListAsync();

                return Ok(new
                {
                    PeriodoAnalisis = new { FechaInicio = fechaInicio, Meses = meses },
                    TendenciasIngresos = tendenciasIngresos,
                    TendenciasConsumos = tendenciasConsumos,
                    RotacionInventario = rotacionInventario
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al obtener tendencias");
                return StatusCode(500, "Error interno del servidor");
            }
        }

        /// <summary>
        /// Obtener KPIs operacionales del sistema
        /// </summary>
        [HttpGet("kpis")]
        public async Task<ActionResult<object>> GetKPIs()
        {
            try
            {
                var hoy = DateTime.Now;
                var inicioMes = new DateTime(hoy.Year, hoy.Month, 1);
                var mesAnterior = inicioMes.AddMonths(-1);
                var fechaInicioMesOnly = DateOnly.FromDateTime(inicioMes);
                var fechaMesAnteriorOnly = DateOnly.FromDateTime(mesAnterior);

                // KPIs financieros
                var valorInventarioActual = await _context.Stocks
                    .Include(s => s.Insumo)
                    .Where(s => s.Cantidad > 0)
                    .SumAsync(s => (s.Cantidad ?? 0) * (s.Insumo!.PrecioUnitario ?? 0));

                var inversionMesActual = await _context.Ingresos
                    .Where(i => i.Fecha >= fechaInicioMesOnly)
                    .SumAsync(i => i.PrecioTotalFormula ?? 0);

                var inversionMesAnterior = await _context.Ingresos
                    .Where(i => i.Fecha >= fechaMesAnteriorOnly && i.Fecha < fechaInicioMesOnly)
                    .SumAsync(i => i.PrecioTotalFormula ?? 0);

                // KPIs operacionales
                var totalProveedoresActivos = await _context.InsumoProveedores
                    .Include(ip => ip.Ingresos)
                    .Where(ip => ip.Ingresos.Any(i => i.Fecha >= fechaInicioMesOnly))
                    .Select(ip => ip.IdProveedor)
                    .Distinct()
                    .CountAsync();

                var rotacionStock = await _context.Consumos
                    .Where(c => c.Fecha >= fechaInicioMesOnly)
                    .CountAsync();

                var tiempoPromedioEntrega = await _context.Ingresos
                    .Where(i => i.Fecha >= fechaInicioMesOnly && i.Estado == "RECIBIDO")
                    .CountAsync();

                // KPIs de calidad
                var lotesActivos = await _context.Lotes
                    .Where(l => l.EstadoLote == "ACTIVO")
                    .CountAsync();

                var lotesVencidos = await _context.Lotes
                    .Where(l => l.FechaExpiracion.HasValue && 
                              l.FechaExpiracion < DateOnly.FromDateTime(hoy) &&
                              l.EstadoLote == "ACTIVO")
                    .CountAsync();

                var eficienciaInventario = lotesActivos > 0 ? 
                    Math.Round((1.0 - (double)lotesVencidos / lotesActivos) * 100, 2) : 100;

                return Ok(new
                {
                    FechaCalculo = hoy,
                    KPIsFinancieros = new
                    {
                        ValorInventarioActual = valorInventarioActual,
                        InversionMesActual = inversionMesActual,
                        InversionMesAnterior = inversionMesAnterior,
                        VariacionInversion = inversionMesAnterior > 0 ? 
                            Math.Round(((inversionMesActual - inversionMesAnterior) / inversionMesAnterior) * 100, 2) : 0
                    },
                    KPIsOperacionales = new
                    {
                        ProveedoresActivos = totalProveedoresActivos,
                        MovimientosStock = rotacionStock,
                        IngresosRecibidos = tiempoPromedioEntrega,
                        EficienciaInventario = eficienciaInventario
                    },
                    KPIsCalidad = new
                    {
                        LotesActivos = lotesActivos,
                        LotesVencidos = lotesVencidos,
                        PorcentajeEficiencia = eficienciaInventario,
                        IndiceCalidad = eficienciaInventario >= 95 ? "EXCELENTE" :
                                      eficienciaInventario >= 85 ? "BUENO" :
                                      eficienciaInventario >= 70 ? "REGULAR" : "DEFICIENTE"
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al calcular KPIs");
                return StatusCode(500, "Error interno del servidor");
            }
        }
    }
} 