# Repositorio de materiales para mantenimiento de PCs   

### Rutinas de análisis y reparación de inconsistencias en archivos de sistema

🧰 **[reparaArchivosSistema.cmd](reparaArchivosSistema.cmd)**   
Ejecuta la reparación de iamgen del sistema operativo (DISM - Deployment Image Servicing and Management) con los siguientes parámetros:
* CheckHealth
* ScanHealth
* RestoreHealth
* StartComponentCleanup   

Luego, ejecuta la reparación de archivos de sistema (sfc - System File Checker)

🧰 **[reparaArchivosSistemaConDEFRAG.cmd](reparaArchivosSistemaConDEFRAG.cmd)**   
Agrega a la ejecución del script anterior una defragmentación de disco.

🧰 **[AnalizadorUsoProgramas.ps1](AnalizadorUsoProgramas.ps1)**   
Rutina que genera un reporte de programas instalados en sistema para evaluar posibles desinstalaciones. Contempla los siguientes puntos:   
* Muestra los programas más grandes (candidatos a desinstalar)
* Muestra programas pequeños
* Crear un archivo de reporte detallado en carpeta **Documents\AnalisisProgramas** del usuario de ejecución.
