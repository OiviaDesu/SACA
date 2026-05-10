param(
    [string]$HostName = "nt.swin.edu.au",
    [string]$User = "dunguyen",
    [string]$LocalRoot = "F:\git\SACA_ML\python_pipeline",
    [string]$RemoteCodeDir = "/home/dunguyen/git/SACA/python_pipeline",
    [string]$RemoteWorkRoot = "/fred/oz396/dunguyen/SACA_ML"
)

$ErrorActionPreference = "Stop"
$Remote = "$User@$HostName"
$RemoteData = "$RemoteWorkRoot/data"

ssh $Remote "mkdir -p '$RemoteCodeDir' '$RemoteData/raw/text' '$RemoteData/raw/structured' '$RemoteData/raw/gurindji' '$RemoteData/processed/hybrid' '$RemoteWorkRoot/outputs/hybrid_mlp'"

$codeItems = @("data_ingestion", "training", "hpc", "requirements", "tests")
foreach ($item in $codeItems) {
    scp -r (Join-Path $LocalRoot $item) "${Remote}:$RemoteCodeDir/"
}

scp -r (Join-Path $LocalRoot "data\raw\text\*") "${Remote}:$RemoteData/raw/text/"
scp -r (Join-Path $LocalRoot "data\raw\structured\*") "${Remote}:$RemoteData/raw/structured/"
if (Test-Path "F:\git\SACA\python_pipeline\data\gurindji_dict_medical.xlsx") {
    scp "F:\git\SACA\python_pipeline\data\gurindji_dict_medical.xlsx" "${Remote}:$RemoteData/raw/gurindji/gurindji_dict_medical.xlsx"
    $localGurindjiCsv = Join-Path $LocalRoot "data\raw\gurindji\gurindji_dict_medical.csv"
    New-Item -ItemType Directory -Force (Split-Path $localGurindjiCsv) | Out-Null
    python -c "import pandas as pd; pd.read_excel(r'F:\git\SACA\python_pipeline\data\gurindji_dict_medical.xlsx').to_csv(r'$localGurindjiCsv', index=False)"
    scp $localGurindjiCsv "${Remote}:$RemoteData/raw/gurindji/gurindji_dict_medical.csv"
}
scp (Join-Path $LocalRoot "data\processed\hybrid\dataset_inventory.json") "${Remote}:$RemoteData/processed/hybrid/dataset_inventory.json"

ssh $Remote "chmod +x '$RemoteCodeDir/hpc/slurm_train_hybrid_mlp.sh' && ls -lh '$RemoteData/raw/text' '$RemoteData/raw/structured'"


