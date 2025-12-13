# Script: AnalizadorProgramas.ps1
# Version completamente limpia - Sin caracteres especiales

param(
    [switch]$ExportarCSV,
    [int]$TopProgramasGrandes = 15,
    [int]$TopProgramasPequenos = 10
)

# Configuracion
$outputDir = "$env:USERPROFILE\Documents\AnalisisProgramas"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$outputFile = "$outputDir\Analisis_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$csvFile = "$outputDir\Analisis_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

Write-Host ""
Write-Host "Recopilando informacion de programas instalados..." -ForegroundColor Cyan

# Funcion para convertir bytes a formato legible
function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -gt 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    elseif ($Bytes -gt 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -gt 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -gt 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    else { return "$Bytes B" }
}

# Funcion para obtener tamano de carpeta con validacion
function Get-FolderSize {
    param([string]$Path)
    
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return 0
    }
    
    if (-not (Test-Path $Path)) {
        return 0
    }
    
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum
        return $size
    }
    catch {
        return 0
    }
}

# Obtener programas instalados del registro
$listaProgramas = @()

# Rutas del registro para programas instalados
$rutasRegistro = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach ($rutaReg in $rutasRegistro) {
    if (Test-Path $rutaReg) {
        $items = Get-ChildItem -Path $rutaReg -ErrorAction SilentlyContinue
        
        foreach ($item in $items) {
            try {
                $propiedades = Get-ItemProperty -Path $item.PSPath -ErrorAction SilentlyContinue
                
                if ($propiedades.DisplayName -and $propiedades.DisplayName -notmatch '^Update for|^Security Update|^Service Pack|^Hotfix') {
                    $nombreMostrar = $propiedades.DisplayName.Trim()
                    $ubicacionInstalacion = $propiedades.InstallLocation
                    
                    # Obtener tamano
                    $tamano = Get-FolderSize -Path $ubicacionInstalacion
                    
                    # Crear objeto del programa
                    $programa = New-Object PSObject
                    $programa | Add-Member -MemberType NoteProperty -Name "Nombre" -Value $nombreMostrar
                    $programa | Add-Member -MemberType NoteProperty -Name "Version" -Value $(if ($propiedades.DisplayVersion) { $propiedades.DisplayVersion } else { "N/A" })
                    $programa | Add-Member -MemberType NoteProperty -Name "Editor" -Value $(if ($propiedades.Publisher) { $propiedades.Publisher } else { "N/A" })
                    
                    # Manejar fecha de instalacion
                    $fechaInst = $null
                    if ($propiedades.InstallDate) {
                        try {
                            $fechaInst = [DateTime]::ParseExact($propiedades.InstallDate, "yyyyMMdd", $null)
                        } catch {
                            try {
                                $fechaInst = [DateTime]::ParseExact($propiedades.InstallDate, "dd/MM/yyyy", $null)
                            } catch {
                                $fechaInst = $null
                            }
                        }
                    }
                    $programa | Add-Member -MemberType NoteProperty -Name "FechaInstalacion" -Value $fechaInst
                    
                    $programa | Add-Member -MemberType NoteProperty -Name "Ubicacion" -Value $ubicacionInstalacion
                    $programa | Add-Member -MemberType NoteProperty -Name "TamanoBytes" -Value $tamano
                    $programa | Add-Member -MemberType NoteProperty -Name "TamanoFormateado" -Value (Format-FileSize -Bytes $tamano)
                    
                    $listaProgramas += $programa
                }
            }
            catch {
                # Continuar con el siguiente programa si hay error
                continue
            }
        }
    }
}

# Ordenar por tamano
$programasOrdenados = $listaProgramas | Sort-Object -Property TamanoBytes -Descending

# Filtrar programas grandes (mayores a 50MB)
$programasGrandes = $programasOrdenados | Where-Object { $_.TamanoBytes -gt 50MB } | Select-Object -First $TopProgramasGrandes

# Filtrar programas pequenos (menores a 10MB)
$programasPequenos = $programasOrdenados | Where-Object { $_.TamanoBytes -lt 10MB } | Select-Object -First $TopProgramasPequenos

# Mostrar resultados
Write-Host ""
Write-Host "=" * 70 -ForegroundColor Green
Write-Host "ANALISIS DE PROGRAMAS INSTALADOS" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

Write-Host ""
Write-Host "RESUMEN:" -ForegroundColor Cyan
Write-Host "  Total de programas encontrados: $($listaProgramas.Count)"
Write-Host "  Programas que ocupan mas de 50 MB: $($programasGrandes.Count)"
$espacioTotal = ($listaProgramas | Measure-Object -Property TamanoBytes -Sum).Sum
Write-Host "  Espacio total aproximado: $(Format-FileSize -Bytes $espacioTotal)"

Write-Host ""
Write-Host "TOP $TopProgramasGrandes PROGRAMAS QUE MAS ESPACIO OCUPAN (candidatos a desinstalar):" -ForegroundColor Yellow
$contador = 1
foreach ($programa in $programasGrandes) {
    if ($programa.TamanoBytes -gt 1GB) {
        $color = "Red"
    } elseif ($programa.TamanoBytes -gt 500MB) {
        $color = "Yellow"
    } else {
        $color = "White"
    }
    
    Write-Host "  $contador. $($programa.Nombre)" -ForegroundColor $color
    Write-Host "     Tamano: $($programa.TamanoFormateado)" -ForegroundColor $color
    Write-Host "     Editor: $($programa.Editor)" -ForegroundColor $color
    if ($programa.FechaInstalacion) {
        Write-Host "     Instalado: $($programa.FechaInstalacion.ToString('dd/MM/yyyy'))" -ForegroundColor Gray
    }
    $contador++
}

Write-Host ""
Write-Host "PROGRAMAS PEQUENOS (menos de 10 MB):" -ForegroundColor Gray
$contador = 1
foreach ($programa in $programasPequenos) {
    Write-Host "  $contador. $($programa.Nombre) - $($programa.TamanoFormateado)" -ForegroundColor Gray
    $contador++
}

# Exportar resultados a archivo de texto
Write-Host ""
Write-Host "EXPORTANDO RESULTADOS..." -ForegroundColor Cyan

$reporte = @"
ANALISIS DE PROGRAMAS INSTALADOS
Fecha: $(Get-Date)
Equipo: $env:COMPUTERNAME
Usuario: $env:USERNAME

RESUMEN:
Total programas encontrados: $($listaProgramas.Count)
Programas que ocupan mas de 50 MB: $($programasGrandes.Count)
Espacio total aproximado: $(Format-FileSize -Bytes $espacioTotal)

TOP $TopProgramasGrandes PROGRAMAS QUE MAS ESPACIO OCUPAN:
$($programasGrandes | Format-Table -Property @{Name="Nombre";Expression={$_.Nombre}}, @{Name="Tamano";Expression={$_.TamanoFormateado}}, @{Name="Editor";Expression={$_.Editor}}, @{Name="Fecha Instalacion";Expression={if($_.FechaInstalacion){$_.FechaInstalacion.ToString('dd/MM/yyyy')}else{'N/A'}}} -AutoSize | Out-String)

LISTA COMPLETA DE PROGRAMAS (ordenados por tamano):
$($programasOrdenados | Format-Table -Property @{Name="Nombre";Expression={$_.Nombre}}, @{Name="Tamano";Expression={$_.TamanoFormateado}}, @{Name="Version";Expression={$_.Version}}, @{Name="Editor";Expression={$_.Editor}} -AutoSize | Out-String)
"@

$reporte | Out-File -FilePath $outputFile -Encoding UTF8
Write-Host "  Reporte guardado en: $outputFile" -ForegroundColor Green

# Exportar a CSV si se solicita
if ($ExportarCSV) {
    $programasOrdenados | Select-Object Nombre, Version, Editor, TamanoFormateado, Ubicacion | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
    Write-Host "  CSV exportado en: $csvFile" -ForegroundColor Green
}

# Recomendaciones
Write-Host ""
Write-Host "RECOMENDACIONES:" -ForegroundColor Cyan
Write-Host "  1. Para desinstalar programas usa:"
Write-Host "     - Panel de Control > Programas y caracteristicas"
Write-Host "     - Configuracion > Aplicaciones > Aplicaciones y caracteristicas"
Write-Host ""
Write-Host "  2. Considera desinstalar programas que:"
Write-Host "     - Ocupan mas de 500 MB y no usas regularmente"
Write-Host "     - Tienen mas de 1 ano sin usar"
Write-Host "     - Son de editores desconocidos o que ya no necesitas"
Write-Host ""
Write-Host "  3. Antes de desinstalar:"
Write-Host "     - Verifica si el programa es necesario para el sistema"
Write-Host "     - Comprueba si hay versiones portables o alternativas mas ligeras"
Write-Host "     - Haz una copia de seguridad de configuraciones importantes"

Write-Host ""
Write-Host "Analisis completado exitosamente!" -ForegroundColor Green
Write-Host "Los resultados se han guardado en: $outputDir" -ForegroundColor Gray
