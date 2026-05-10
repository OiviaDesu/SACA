param(
    [string]$HostName = "nt.swin.edu.au",
    [string]$User = "dunguyen",
    [string]$LocalOutput = "F:\git\SACA_ML\python_pipeline\outputs\hybrid_mlp",
    [string]$RemoteOutput = "/fred/oz396/dunguyen/SACA_ML/outputs/hybrid_mlp"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force $LocalOutput | Out-Null
$Remote = "$User@$HostName"
scp "${Remote}:$RemoteOutput/hybrid_mlp.joblib" $LocalOutput
scp "${Remote}:$RemoteOutput/metrics.json" $LocalOutput
scp "${Remote}:$RemoteOutput/label_report.csv" $LocalOutput
scp "${Remote}:$RemoteOutput/predict_smoke.json" $LocalOutput

