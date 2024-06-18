# Definiowanie ścieżki do plików .dtsx
$wb_pod_path = "wb_pod.dtsx"
$wb_na_path = "wb_na.dtsx"
$wb_poz_path = "wb_poz.dtsx"
$wb_wiersz_path = "wb_wiersz.dtsx"

# Uruchamianie komendy dtexec dla każdego pliku .dtsx
Write-Host "Uruchamianie wb_pod.dtsx..."
dtexec /F $wb_pod_path

Write-Host "Uruchamianie wb_na.dtsx..."
dtexec /F $wb_na_path

Write-Host "Uruchamianie wb_poz.dtsx..."
dtexec /F $wb_poz_path

Write-Host "Uruchamianie wb_wiersz.dtsx..."
dtexec /F $wb_wiersz_path

Write-Host "Wykonano wszystkie zadania."