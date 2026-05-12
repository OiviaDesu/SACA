from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).with_name('data_ingestion') / '04_gurindji_synthetic_dataset.py'), run_name='__main__')
