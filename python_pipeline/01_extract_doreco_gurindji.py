from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).with_name('data_ingestion') / '01_extract_doreco_gurindji.py'), run_name='__main__')
